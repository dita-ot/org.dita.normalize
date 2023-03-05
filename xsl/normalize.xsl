<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2015 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                exclude-result-prefixes="xs ditaarch dita-ot xsi"
                version="2.0">

  <xsl:import href="plugin:org.dita.base:xsl/common/uri-utils.xsl"/>

  <xsl:param name="output.dir.uri" as="xs:string"/>
  <xsl:param name="normalize-strip-keyref" as="xs:string"/>
  <xsl:param name="normalize-strip-branch-filter" as="xs:string"/>

  <xsl:function name="dita-ot:get-fragment" as="xs:string">
    <xsl:param name="input" as="xs:string"/>
    <xsl:sequence select="replace($input, '^[^#]+', '')"/>
  </xsl:function>

  <xsl:function name="dita-ot:strip-fragment" as="xs:anyURI">
    <xsl:param name="input" as="xs:string"/>
    <xsl:sequence select="xs:anyURI(replace($input, '#.*$', ''))"/>
  </xsl:function>

  <xsl:function name="dita-ot:set-fragment" as="xs:anyURI">
    <xsl:param name="path" as="xs:string"/>
    <xsl:param name="fragment" as="xs:string"/>
    <xsl:sequence select="xs:anyURI(concat($path, $fragment))"/>
  </xsl:function>

  <xsl:variable name="files" as="document-node()">
    <xsl:variable name="rewritten" as="element()*">
      <xsl:for-each select="job/files/file[@format = ('dita', 'ditamap')]">
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:attribute name="uri" select="resolve-uri(@uri, base-uri($root))"/>
          <xsl:choose>
            <xsl:when test="matches(@uri, '\.(xml|dita|ditamap)$', 'i')">
              <xsl:attribute name="result" select="@uri"/>
              <xsl:attribute name="renamed" select="false()"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="result" select="replace(@uri, '\.(\w+)$', concat('.', @format))"/>
              <xsl:attribute name="renamed" select="true()"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:copy>
      </xsl:for-each>
    </xsl:variable>
    <xsl:document>
      <xsl:for-each-group select="$rewritten" group-by="@result">
        <xsl:variable name="path" select="replace(current-grouping-key(), '#.*$', '')" as="xs:string"/>
        <xsl:variable name="fragment" select="replace(current-grouping-key(), '^[^#]+', '')" as="xs:string"/>
        <xsl:for-each select="current-group()">
          <xsl:sort select="@renamed"/>
          <xsl:copy>
            <xsl:copy-of select="@* except @renamed"/>
            <xsl:attribute name="result" select="replace(@result, '\.(\w+)$',
                if (position() eq 1)
                then '.$1'
                else concat('-', position() - 1, '.$1'))"/>
          </xsl:copy>
        </xsl:for-each>
      </xsl:for-each-group>
    </xsl:document>
  </xsl:variable>

  <xsl:key name="file-uri" match="file" use="@uri"/>

  <xsl:variable name="root" select="." as="document-node()"/>

  <xsl:template match="/">
    <xsl:for-each select="$files/*">
      <xsl:variable name="input.uri" select="resolve-uri(@uri, base-uri($root))"/>
      <xsl:variable name="output.uri" select="concat($output.dir.uri, @result)"/>
      <xsl:message select="concat('Writing ', $output.uri)"/>
      <xsl:for-each select="document($input.uri)">
        <xsl:choose>
          <xsl:when test="*/@xsi:noNamespaceSchemaLocation">
            <xsl:result-document href="{$output.uri}">
              <xsl:apply-templates>
                <xsl:with-param name="uri" select="$input.uri" as="xs:anyURI" tunnel="yes"/>
              </xsl:apply-templates>
            </xsl:result-document>
          </xsl:when>
          <xsl:otherwise>
            <xsl:result-document href="{$output.uri}"
                                 doctype-public="{dita-ot:get-doctype-public(.)}"
                                 doctype-system="{dita-ot:get-doctype-system(.)}">
              <xsl:apply-templates>
                <xsl:with-param name="uri" select="$input.uri" as="xs:anyURI" tunnel="yes"/>
              </xsl:apply-templates>
            </xsl:result-document>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

  <xsl:function name="dita-ot:get-doctype-public">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:choose>
      <xsl:when test="$doc/processing-instruction('doctype-public')">
        <xsl:value-of select="$doc/processing-instruction('doctype-public')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>-//OASIS//DTD DITA </xsl:text>
        <xsl:choose>
          <xsl:when test="$doc/dita">Composite</xsl:when>
          <xsl:when test="$doc/*[contains(@class, ' bookmap/bookmap ')]">BookMap</xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="upper-case(substring(name($doc/*), 1, 1))"/>
            <xsl:value-of select="lower-case(substring(name($doc/*), 2))"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text>//EN</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="dita-ot:get-doctype-system">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:choose>
      <xsl:when test="$doc/processing-instruction('doctype-system')">
        <xsl:value-of select="$doc/processing-instruction('doctype-system')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="name($doc/*)"/>
        <xsl:text>.dtd</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Remove default attributes from schema -->
  <xsl:template match="@class | @domains | @specializations | @xtrf | @xtrc | @ditaarch:DITAArchVersion"
                priority="10"/>

  <!-- Remove processing time PIs -->
  <xsl:template match="processing-instruction('workdir') |
                       processing-instruction('workdir-uri') |
                       processing-instruction('path2project') |
                       processing-instruction('path2project-uri') |
                       processing-instruction('path2rootmap-uri') |
                       processing-instruction('ditaot') |
                       processing-instruction('doctype-public') |
                       processing-instruction('doctype-system') |
                       @dita-ot:* |
                       @mapclass"
                priority="10"/>

  <!-- Remove cascade inserted by preprocess -->
  <xsl:template match="*[number(@ditaarch:DITAArchVersion) &lt; 1.3]/@cascade"/>

  <!-- Rename elements to match class type -->
  <xsl:template match="*[@class]" priority="-5">
    <xsl:element name="{tokenize(tokenize(normalize-space(@class), '\s+')[last()], '/')[last()]}"
      namespace="{namespace-uri()}">
      <xsl:apply-templates select="node() | @*"/>
    </xsl:element>
  </xsl:template>

  <!-- Remove resolved keydefs -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]
                        [exists(@keys) and @processing-role = 'resource-only']
                        [$normalize-strip-keyref = 'true']"/>

  <!-- Remove resolved key definition and references -->
  <xsl:template match="@keyref[$normalize-strip-keyref = 'true'] |
                       @keys[$normalize-strip-keyref = 'true']"/>

  <!-- Remove resolved ditavalrefs -->
  <xsl:template match="*[contains(@class, ' ditavalref-d/ditavalref ')]
                        [$normalize-strip-branch-filter = 'true']"/>

  <!-- Rewrite link target -->
  <xsl:template match="*[contains(@class, ' topic/xref ') or
                         contains(@class, ' topic/link ') or
                         (contains(@class, ' topic/keyword') and exists(@href)) or
                         contains(@class, ' map/topicref ')]
                        [empty(@format) or @format = 'dita']
                        [empty(@scope) or @scope = 'local']/@href">
    <xsl:param name="uri" as="xs:anyURI" tunnel="yes"/>
    <xsl:variable name="input" select="resolve-uri(., $uri)" as="xs:string"/>
    <xsl:variable name="path" select="dita-ot:strip-fragment($input)" as="xs:anyURI"/>
    <xsl:variable name="fragment" select="dita-ot:get-fragment($input)" as="xs:string"/>
    <xsl:variable name="href" select="key('file-uri', $path, $files)/@result" as="xs:anyURI?"/>
    <xsl:choose>
      <xsl:when test="exists($href)">
        <xsl:attribute name="{name()}" select="dita-ot:set-fragment(
          dita-ot:relativize(
            resolve-uri('.',$uri),
            resolve-uri($href, base-uri($root))),
          $fragment)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Rename keyword that has been converted into a link using keys -->
  <xsl:template match="*[contains(@class, ' topic/keyword ') and exists(@href)]">
    <xref>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="class">- topic/xref </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </xref>
  </xsl:template>

  <!-- Remove default attributes -->
  <xsl:template match="*[contains(@class, ' topic/pre ')]/@xml:space[. = 'preserve'] |
                       @scope[. = 'local'] |
                       @format[. = 'dita'] |
                       *[contains(@class, ' topic/xref ')]/@locktitle"/>

  <xsl:template match="*[contains(@class, ' subjectScheme/')]" priority="5"/>

  <!-- Remove colname inserted by preprocess -->
  <xsl:template match="*[contains(@class, ' topic/entry ')]/@colname">
    <xsl:if test="empty(../@namest) and empty(../@nameend)">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" priority="-10">
    <xsl:element name="{name()}" namespace="{namespace-uri()}">
      <xsl:apply-templates select="node() | @*"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="node() | @*" priority="-15">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
