" />
			<xs:element ref="ListStructure" />
			<xs:element ref="TableStructure" />
			<xs:element ref="FigureStructure" />
		</xs:choice>
	</xs:complexType>
	<xs:complexType name="CT_Paragraph">
		<xs:choice minOccurs="0" maxOccurs="unbounded">
			<xs:element ref="NamedElement" />
		</xs:choice>
	</xs:complexType>
	<xs:complexType name="CT_Table">
		<xs:choice maxOccurs="unbounded">
			<xs:element ref="TableRowGroupStructure" />
		</xs:choice>
	</xs:complexType>
	<xs:complexType name="CT_TableRowGroup">
		<xs:choice maxOccurs="unbounded">
			<xs:element ref="TableRowStructure" />
		</xs:choice>
	</xs:complexType>
	<xs:complexType name="CT_TableRow">
		<xs:cho