<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output encoding="koi8-r"/>


<xsl:template match="/">
  <article>
     <table align="center" width="600" cellpadding="10"><tr>
     <td width="20%" bgcolor="#f0f0f0"></td>
     <td width="80%">
      <h1 align="right"><xsl:value-of select="article/@title"/></h1>
		  <xsl:apply-templates/>
     </td></tr></table>
  </article>
</xsl:template>

<xsl:template match="term">
<b><xsl:value-of select="text()"/></b>
</xsl:template>

<xsl:template match="tech">
<i><xsl:value-of select="text()"/></i>
</xsl:template>

<xsl:template match="table">
<table width="100%">
<tr><td align="right">
<font size="-2" color="#666666" face="Verdana, Arial, Helvetica, sans-serif"><i><xsl:value-of select="@name"/></i></font>
</td></tr>
<tr><td align="right">
<table align="right" bgcolor="black" width="95%" cellpadding="3" cellspacing="1">
  <xsl:for-each select="tr">
   <xsl:variable name="bgcolor">
 		<xsl:choose>
      <xsl:when test="position() mod 2">#e8e8e8</xsl:when>
      <xsl:otherwise>#f0f0f0</xsl:otherwise>
    </xsl:choose>
   </xsl:variable>
    <tr>
      <xsl:for-each select="td|th">
				<td bgcolor="{$bgcolor}">
				   <font size="-2" color="#333333" face="Verdana, Arial, Helvetica, sans-serif"><xsl:apply-templates/></font>
				</td>
      </xsl:for-each>
    </tr>
  </xsl:for-each>
</table>
</td></tr></table>
<br/>
</xsl:template>


<xsl:template match="p">
<p align="justify"><font size="-1
" color="#333333" face="Verdana, Arial, Helvetica, sans-serif"><xsl:apply-templates/></font></p>
</xsl:template>

<xsl:template match="file">
<i><xsl:apply-templates/></i>
</xsl:template>

<xsl:template match="url">
<font size="-1" color="blue" face="Verdana, Arial, Helvetica, sans-serif"><xsl:apply-templates/></font>
</xsl:template>


<xsl:template match="list">
	<xsl:if test="@type='ordered'">
		<ol>
			<xsl:apply-templates/>
		</ol>
	</xsl:if>
	<xsl:if test="@type='unordered'">
		<ul>
			<xsl:apply-templates/>
		</ul>
	</xsl:if>
</xsl:template>

<xsl:template match="list/item">
<li><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="list/l">
<li/>
</xsl:template>

<xsl:template match="code">
<pre><font size="-2" face="Fixed"><xsl:apply-templates/></font></pre>
</xsl:template>

<xsl:template match="note">
<blockquote><font size="-1" color="black" face="Courier">
<xsl:apply-templates/>
</font></blockquote>
</xsl:template>


<!--
<xsl:template match="B|I|U">
<xsl:element name="{name()}">
<xsl:apply-templates/>
</xsl:element> </xsl:template>
-->


<xsl:template name="htmLink">
	<xsl:param name="dest" select="UNDEFINED"/>
  <xsl:element name="a">
    <xsl:attribute name="href">
      <xsl:value-of select="$dest"/>
    </xsl:attribute>
    <xsl:apply-templates/>
  </xsl:element>
</xsl:template>


<xsl:template match="link">
  <xsl:if test="@target">
    <xsl:call-template name="htmLink">
      <xsl:with-param name="dest" select="@target"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>



<xsl:template match="/ARTICLE/SECT/SECT/SECT">
	<xsl:message terminate="yes">Error: Sections can only be nested 2 deep.</xsl:message>
</xsl:template>



</xsl:stylesheet>