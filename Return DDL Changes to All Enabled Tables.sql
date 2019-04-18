	</xs:sequence>
	</xs:complexType>
	<xs:complexType name="CT_CP_Outline">
 		<xs:sequence>
 			<xs:element ref="DocumentOutline" />
 		</xs:sequence>
 	</xs:complexType>
	<xs:complexType name="CT_DocumentOutline">
		<xs:sequence>
			<xs:element ref="OutlineEntry" maxOccurs="unbounded" />
		</xs:sequence>
		<xs:attributeGroup ref="AG_DocumentOutline" />
	</xs:complexType>
	<xs:complexType name="CT_OutlineEntry">
		<xs:attributeGroup ref="AG_OutlineEntry" />
	</xs:complexType>
	<xs:complexType name="CT_Story">
		<xs:sequence>
			<xs:element ref="StoryFragmentReference" maxOccurs="unbounded" />
		</xs:sequence>
		<xs:attributeGroup ref="AG_Story" />
	</xs:complexType>
	<xs:complexType name="CT_StoryFragmentReference">
		<xs:attributeGroup ref="AG_StoryFragmentReference" />
	</xs:complexType>
	<!-- Simple Types -->
	<!-- A Name (ID with pattern restriction according to XPS spec) -->
	<xs:simpleType name="ST_Name">
		<xs:restriction base="xs:string">
			<xs:pattern value="(\p{Lu}|\p{Ll}|\p{Lo}|\p{Lt}|\p{Nl})(\p{Lu}|\p{Ll}|\p{Lo}|\p{Lt}|\p{Nl}|\p{Mn}|\p{Mc}|\p{Nd}|\p{Lm}|_)*" />
		</xs:restriction>
	</xs:simpleType>
	<!-- A Unique Name (ID with pattern restriction according to XPS spec) -->
	<xs:simpleType name="ST_NameUnique">
		<xs:restriction base="xs:ID">
			<xs:pattern value="(\p{Lu}|\p{Ll}|\p{Lo}|\p{Lt}|\p{Nl})(\p{Lu}|\p{Ll}|\p{Lo}|\p{Lt}|\p{Nl}|\p{Mn}|\p{Mc}|\p{Nd}|\p{Lm}|_)*" />
		</xs:restriction>
	</xs:simpleType>
	<!-- integer greater than or equal to 1 inclusive -->
	<xs:simpleType name="ST_IntGEOne">
		<xs:restriction base="xs:int">
			<xs:minInclusive