<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mml="http://www.w3.org/1998/Math/MathML"
  xmlns:mml2tex="http://transpect.io/mml2tex"
  xmlns="http://www.w3.org/1998/Math/MathML"
  version="2.0"
  exclude-result-prefixes="mml xs" 
  xpath-default-namespace="http://www.w3.org/1998/Math/MathML">
  
  <!--  *
        * remove empty equation objects
        * -->
  
  <xsl:import href="operators.xsl"/>
  <xsl:import href="function-names.xsl"/>
  
  <xsl:variable name="whitespace-regex" select="'\p{Zs}&#x200b;-&#x200f;'" as="xs:string"/>
  <xsl:variable name="wrapper-element-names" select="('msup', 'msub', 'msubsup', 'mfrac', 'mroot', 'mmultiscripts')" as="xs:string+"/>
  
  <xsl:template match="mml:math[every $i in .//mml:* 
                                satisfies (string-length(normalize-space($i)) eq 0 and not($i/@*))]
                       |//processing-instruction('mathtype')[string-length(normalize-space(replace(., '\$', ''))) eq 0]" mode="mml2tex-preprocess">
    <xsl:message select="'[WARNING] empty equation removed:&#xa;', ."/>
    <xsl:processing-instruction name="latex" select="'% empty equation removed. ', replace(., '[\n&#xa;]+', '')"/>
  </xsl:template>
  
  <!--  *
        * group adjacent mi and mtext tags with equivalent attributes
        * -->
  
  <xsl:template match="*[count(mi) gt 1 or count(mtext) gt 1]
                        [not(local-name() = $wrapper-element-names)]" mode="mml2tex-grouping">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      
      <xsl:for-each-group select="*" 
        group-adjacent="concat(name(), 
                               string-join(for $i in @* except @xml:space return concat($i/local-name(), $i), '-'),
                               matches(., concat('^[\p{L}\p{P}', $whitespace-regex, ']+$'), 'i')
                               )">
          <xsl:choose>
            <xsl:when test="(current-group()/self::mtext or current-group()/self::mi[@mathvariant])">
              <xsl:copy>
                <xsl:apply-templates select="current-group()/@*, current-group()/node()" mode="#current"/>
              </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="current-group()" mode="#current"/>
            </xsl:otherwise>
          </xsl:choose>
        
      </xsl:for-each-group>
      
    </xsl:copy>
  </xsl:template>
  
  <!-- conclude three single mo elements with the '.' character to horizontal ellipsis -->
  <xsl:template match="mo[. = '.']
                         [preceding-sibling::*[1]/self::mo[. = '.'][not(preceding-sibling::*[1]/self::mo[. = '.'])]]
                         [following-sibling::*[1]/self::mo[. = '.'][not(following-sibling::*[1]/self::mo[. = '.'])]]" mode="mml2tex-preprocess">
    <mo>
      <xsl:value-of select="'&#x2026;'"/>
    </mo>
  </xsl:template>
  <xsl:template match="  mo[. = '.']
                           [not(following-sibling::*[1]/self::mo[. = '.'])]
                           [preceding-sibling::*[1]/self::mo[. = '.']]
                           [preceding-sibling::*[2]/self::mo[. = '.']]
                           [not(preceding-sibling::*[3]/self::mo[. = '.'])]
                       | mo[. = '.']
                           [not(preceding-sibling::*[1]/self::mo[. = '.'])]
                           [following-sibling::*[1]/self::mo[. = '.']]
                           [following-sibling::*[2]/self::mo[. = '.']]
                           [not(following-sibling::*[3]/self::mo[. = '.'])]" mode="mml2tex-preprocess"/>
  
  <!-- resolve empty mi, mn, mo -->
  
  <xsl:template match="mi[not(normalize-space(.)) and not(processing-instruction())]
                      |mo[not(normalize-space(.)) and not(processing-instruction())]
                      |mn[not(normalize-space(.)) and not(processing-instruction())]" mode="mml2tex-preprocess"/>
  
  <!-- resolve msubsup if superscript and subscript is empty -->
  
  <xsl:template match="msubsup[every $i in (*[2], *[3]) satisfies matches($i, concat('^[', $whitespace-regex, ']+$')) or not(exists($i/node()))]" priority="10" mode="mml2tex-preprocess">
    <xsl:apply-templates select="*[1]" mode="#current"/>
  </xsl:template>
  
  <!-- convert msubsup to msub if superscript is empty -->
  
  <xsl:template match="msubsup[exists(*[2]/node()) and (matches(*[3], concat('^[', $whitespace-regex, ']+$')) or not(exists(*[3]/node())))]" mode="mml2tex-preprocess">
    <msub xmlns="http://www.w3.org/1998/Math/MathML">
      <xsl:apply-templates select="@*, node() except *[3]" mode="#current"/>
    </msub>
  </xsl:template>

  <!-- regroup msubsups with empty argument -->
  
  <xsl:template match="*[local-name() = ('mi', 'mn', 'mtext')][following-sibling::*[1][local-name() eq 'msubsup' 
                                                               and *[1][matches(., concat('[', $whitespace-regex, ']'))]
                                                               and not(*[2][matches(., concat('[', $whitespace-regex, ']'))])
                                                               and not(*[3][matches(., concat('[', $whitespace-regex, ']'))])
                                                               ]]" mode="mml2tex-preprocess"/>
  
  <xsl:template match="msubsup[preceding-sibling::*[1][local-name() = ('mi', 'mn', 'mtext')]]/*[1][matches(., concat('[', $whitespace-regex, ']'))]" mode="mml2tex-preprocess">
    <xsl:copy-of select="parent::*/preceding-sibling::*[1]"/>
  </xsl:template>

  <!-- convert msubsup to msup if subscript is empty -->
  
  <xsl:template match="msubsup[exists(*[3]/node()) 
                               and (matches(*[2], concat('^[', $whitespace-regex, ']+$')) 
                                    or not(exists(*[2]/node())))]" mode="mml2tex-preprocess">
    <msup xmlns="http://www.w3.org/1998/Math/MathML">
      <xsl:apply-templates select="@*, node() except *[2]" mode="#current"/>
    </msup>
  </xsl:template>
  
  <!-- resolve msub/msup with empty exponent -->
  
  <xsl:template match="msub[matches(*[2], concat('^[', $whitespace-regex, ']+$')) or not(exists(*[2]/node()))]
                      |msup[matches(*[2], concat('^[', $whitespace-regex, ']+$')) or not(exists(*[2]/node()))]" mode="mml2tex-preprocess">
    <xsl:apply-templates select="*[1]" mode="#current"/>
  </xsl:template>
  
  <!-- resolve mspace less equal than 0.25em -->

  <xsl:template match="mspace[xs:decimal(replace(@width, '[a-z]+$', '')) le 0.25][not(preceding-sibling::*[1]/self::mtext or following-sibling::*[1]/self::mtext)]" mode="mml2tex-preprocess"/>

  <!-- repair msup/msub with more than two child elements. We assume the last node was superscripted/subscripted -->

  <xsl:template match="msup[count(*) gt 2]
		                  |msub[count(*) gt 2]" mode="mml2tex-preprocess">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <mrow xmlns="http://www.w3.org/1998/Math/MathML">
        <xsl:apply-templates select="*[not(position() eq last())]" mode="#current"/>
      </mrow>
      <xsl:apply-templates select="*[position() eq last()]" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- resolve nested mmultiscripts when authors put tensors in the base of tensors by accident (MS Word equation editor) -->
  
  <xsl:template match="mmultiscripts/mrow[mmultiscripts]" mode="mml2tex-preprocess">
    <xsl:copy>
      <xsl:apply-templates select="@*, *[1]" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="mmultiscripts[mrow/mmultiscripts]" mode="mml2tex-preprocess">
    <xsl:copy>
      <xsl:apply-templates select="@*, node()" mode="#current"/>
    </xsl:copy>
    <xsl:apply-templates select="mrow/*[position() gt 1]" mode="#current"/>
  </xsl:template>
  
    <xsl:variable name="non-text-element-names" as="xs:string*"
    select="('mfrac', 'mn', 'mo')"/>
  
  <xsl:template match="mtext[matches(., '^[\p{Zs}&#x200b;]+$')]
                            [
                              preceding-sibling::*[1][local-name() = $non-text-element-names]
                              and
                              following-sibling::*[1][local-name() = $non-text-element-names]
                            ]" mode="mml2tex-preprocess"/>
  
  <!-- wrap private use and non-unicode-characters in mglyph -->
  
  <xsl:template match="text()[matches(., '[&#xE000;-&#xF8FF;&#xF0000;-&#xFFFFF;&#x100000;-&#x10FFFF;]')]" mode="mml2tex-preprocess">
    <xsl:analyze-string select="." regex="[&#xE000;-&#xF8FF;&#xF0000;-&#xFFFFF;&#x100000;-&#x10FFFF;]">
      <xsl:matching-substring>
        <mglyph alt="{.}"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>
  
  <!-- parse mtext and map to proper mathml elements -->
  
  <xsl:variable name="mi-regex" select="concat('((', $mml2tex:functions-names-regex, ')|([\p{L}])' ,')')" as="xs:string"/>
  
  <xsl:template match="mtext[matches(., concat('^\s*', $mi-regex, '\s*$'))]" mode="mml2tex-preprocess">
    <xsl:element name="{mml:gen-name(parent::*, 'mi')}">
      <xsl:attribute name="mathvariant" select="'normal'"/>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:value-of select="normalize-space(.)"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="mtext[matches(., '^\s*[0-9]+\s*$')]" mode="mml2tex-preprocess">
    <xsl:element name="{mml:gen-name(parent::*, 'mn')}">
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:value-of select="normalize-space(.)"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:variable name="non-whitespace-element-names" select="('mn', 'mo')" as="xs:string+"/>
  
  <xsl:template match="mtext[matches(., concat('^[', $whitespace-regex, ']+$'))]
                            [not(parent::*/local-name() = $wrapper-element-names)]
                            [preceding::node()[1]/ancestor-or-self::*[local-name() = ($non-whitespace-element-names, $non-text-element-names)] or
                             following::node()[1]/self::*[local-name() = ($non-whitespace-element-names, $non-text-element-names)]]" mode="mml2tex-preprocess"/>
  
  <xsl:template match="mtext[matches(., concat('^\s*', $mml2tex:operators-regex, '\s*$'))][not(matches(., concat('^[', $whitespace-regex, ']+$')))]" mode="mml2tex-preprocess">
    <xsl:element name="{mml:gen-name(parent::*, 'mo')}">
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:value-of select="normalize-space(.)"/>
    </xsl:element>
  </xsl:template>
  
  <!-- to-do group mtext in 1st mode and text heurstics in another mode or try matching to mtext/text() -->
  
  <xsl:template match="mtext[not(matches(., concat('^[', $whitespace-regex, ']+$')))]" mode="mml2tex-preprocess" priority="10">
    <xsl:variable name="new-mathml" as="element()+">
      <xsl:variable name="parent" select="parent::*" as="element()"/>
      <xsl:variable name="regular-words-regex" select="'(\p{L}\p{L}+)([-\s]\p{L}\p{L}+)+\s*'" as="xs:string"/>
      <xsl:analyze-string select="." regex="{$regular-words-regex}">
  
        <!-- preserve hyphenated words -->
        <xsl:matching-substring>
          <xsl:element name="{mml:gen-name($parent, 'mtext')}">
            <xsl:value-of select="."/>
          </xsl:element>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
      
          <!-- tag operators -->
          <xsl:analyze-string select="." regex="{$mml2tex:operators-regex}">
            
            <xsl:matching-substring>
              <xsl:element name="{mml:gen-name($parent, 'mo')}">
                <xsl:value-of select="normalize-space(.)"/>
              </xsl:element>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
              
              <xsl:analyze-string select="." regex="{concat('(\s', $mi-regex, '\s)|(^\s?', $mi-regex, '\s?$)|(\s', $mi-regex, '$)|(^', $mi-regex, '\s)')}">
                
                <!-- tag identifiers -->
                <xsl:matching-substring>
                  <xsl:element name="{mml:gen-name($parent, 'mi')}">
                    <xsl:attribute name="mathvariant" select="'normal'"/>
                    <xsl:value-of select="normalize-space(.)"/>
                  </xsl:element>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                  
                  <!-- tag numerical values -->
                  <xsl:analyze-string select="." regex="[0-9]+">
                    
                    <xsl:matching-substring>
                      <xsl:element name="{mml:gen-name($parent, 'mn')}">
                        <xsl:value-of select="normalize-space(.)"/>
                      </xsl:element>
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                      
                      <!-- tag derivates -->
                      <xsl:analyze-string select="." regex="([a-zA-Z])(')+">
                        
                        <xsl:matching-substring>
                          <xsl:element name="{mml:gen-name($parent, 'mi')}">
                            <xsl:attribute name="mathvariant" select="'normal'"/>
                            <xsl:value-of select="regex-group(1)"/>
                          </xsl:element>
                          <xsl:element name="{mml:gen-name($parent, 'mo')}">
                            <xsl:value-of select="regex-group(2)"/>
                          </xsl:element>
                        </xsl:matching-substring>
                        
                        <xsl:non-matching-substring>
                          
                          <!-- tag greeks  -->
                          <xsl:analyze-string select="." regex="[&#x391;-&#x3c9;]">
                            
                            <xsl:matching-substring>
                              <xsl:element name="{mml:gen-name($parent, 'mi')}">
                                <xsl:attribute name="mathvariant" select="'normal'"/>
                                <xsl:value-of select="normalize-space(.)"/>
                              </xsl:element>
                            </xsl:matching-substring>
                            <xsl:non-matching-substring>
                              <!-- map characters to mi -->
                              <xsl:choose>
                                <xsl:when test="string-length(normalize-space(.)) eq 1">
                                  <xsl:element name="{mml:gen-name($parent, 'mi')}">
                                    <xsl:attribute name="mathvariant" select="'normal'"/>
                                    <xsl:value-of select="normalize-space(.)"/>
                                  </xsl:element>
                                </xsl:when>
                                <xsl:when test="normalize-space(.)">
                                  <xsl:element name="{mml:gen-name($parent, 'mtext')}">
                                    <xsl:value-of select="."/>
                                  </xsl:element>
                                </xsl:when>
                              </xsl:choose>
                            </xsl:non-matching-substring>
                            
                          </xsl:analyze-string>
                        </xsl:non-matching-substring>
                      </xsl:analyze-string>
                    </xsl:non-matching-substring>
                  </xsl:analyze-string>     
                </xsl:non-matching-substring>
              </xsl:analyze-string>
            </xsl:non-matching-substring>
          </xsl:analyze-string>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="count($new-mathml) gt 1">
        <mrow xmlns="http://www.w3.org/1998/Math/MathML">
          <xsl:sequence select="$new-mathml"/>
        </mrow>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$new-mathml"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="mml:gen-name" as="xs:string">
    <xsl:param name="parent" as="element()"/>
    <xsl:param name="name" as="xs:string"/>
    <xsl:value-of select="if(matches($parent/name(), ':')) 
                          then concat(substring-before($parent/name(), ':'), ':', $name) 
                          else $name"/>
  </xsl:function>
  
  <!-- identity template -->
  
  <xsl:template match="*|@*|processing-instruction()" mode="mml2tex-grouping mml2tex-preprocess">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()|processing-instruction()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!--<xsl:template match="/" mode="mml2tex-preprocess">
    <xsl:copy>
      <xsl:apply-templates mode="mml2tex-preprocess"/>
    </xsl:copy>
  </xsl:template>-->
  
</xsl:stylesheet>
