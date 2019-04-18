e="Round" />
            <xs:enumeration value="Square" />
            <xs:enumeration value="Triangle" />
        </xs:restriction>
    </xs:simpleType>

    <!-- Line Cap enumeration -->
    <xs:simpleType name="ST_LineCap">
        <xs:restriction base="xs:string">
            <xs:enumeration value="Flat" />
            <xs:enumeration value="Round" />
            <xs:enumeration value="Square" />
            <xs:enumeration value="Triangle" />
        </xs:restriction>
    </xs:simpleType>

    <!-- Line Join enumeration -->
    <xs:simpleType name="ST_LineJoin">
        <xs:restriction base="xs:string">
            <xs:enumeration value="Miter" />
            <xs:enumeration value="Bevel" />
            <xs:enumeration value="Round" />
        </xs:restriction>
    </xs:simpleType>

    <!-- Tile Mode enumeration -->
    <xs:simpleType 