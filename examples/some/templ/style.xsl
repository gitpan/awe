<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" encoding="koi8-r"/>

<xsl:template match="/html">
	<html>
		<head>
      <title>Test</title>
		</head>
	  <body>
	     <xsl:apply-templates/>
	  </body></html>
</xsl:template>

<xsl:template match="*">
<xsl:copy-of  select ="." />
</xsl:template>


</xsl:stylesheet>