class Id {
    [int] $Id = 0
    [int] GetNewId() {
        $this.Id--
        return $this.Id
    }
}
class DataMart {
    [int] $Id
    [guid] $ContentId
    [string] $Name
    [string] $DataMartType
    [string] $Description
    [string] $SqlAgentProxyName
    [string] $SqlCredentialName
    [decimal] $DefaultEngineVersion
    [string] $SystemName
    [string] $DataStewardFullName
    [string] $DataStewardEmail
    [string] $Version
    [string] $IsHidden
    [Connection[]] $Connections
    [Entity[]] $Entities
    [Binding[]] $Bindings
    [ObjectAttributeValue[]] $AttributeValues
}
class Connection {
    [int] $Id
    [guid] $ContentId
    [string] $SystemName
    [string] $Description
    [string] $DataSystemTypeCode
    [string] $DataSystemVersion
    [string] $SystemVendorName
    [string] $SystemVersion
    [ObjectAttributeValue[]] $AttributeValues
}
class Entity {
    [int] $Id
    [guid] $ContentId
    [int] $ConnectionId
    [string] $BusinessDescription
    [string] $EntityName
    [string] $TechnicalDescription
    [string] $PersistenceType
    [bool] $IsPublic
    [bool] $AllowsDataEntry
    [int] $RecordCountMismatchThreshold
    [nullable[int]] $RecordCount
    [nullable[system.datetimeoffset]] $LastSuccessfulLoadTimestamp
    [nullable[system.datetimeoffset]] $LastModifiedTimestamp
    [nullable[system.datetimeoffset]] $LastDeployedTimestamp
    [Field[]] $Fields
    [Index[]] $Indexes
    [ObjectAttributeValue[]] $AttributeValues
}
class Binding {
    [int] $Id
    [guid] $ContentId
    [string] $Name
    [int] $DestinationEntityId
    [int] $SourceConnectionId
    [string] $BindingType
    [string] $Classification
    [string] $Description
    [string] $LoadTypeCode
    [string] $Status
    [string] $GroupingColumn
    [string] $GroupingFormat
    [string] $GrainName
    [ObjectAttributeValue[]] $AttributeValues
}
class Field {
    [int] $Id
    [guid] $ContentId
    [string] $FieldName
    [string] $BusinessDescription
    [string] $TechnicalDescription
    [string] $DataType
    [string] $DefaultValue
    [string] $DataSensitivity
    [nullable[int]] $Ordinal
    [string] $Status
    [string] $ExampleData
    # [nullable[system.datetimeoffset]] $ExampleDataUpdatetimestamp
    [bool] $IsPrimaryKey
    [bool] $IsNullable
    [bool] $IsAutoIncrement
    [bool] $ExcludeFromBaseView
    [bool] $IsSystemField
    [ObjectAttributeValue[]] $AttributeValues
}
class Index {
    [int] $Id
    [guid] $ContentId
    [string] $IndexName
    [bool] $IsUnique
    [bool] $IsActive
    [string] $IndexTypeCode
    [bool] $IsColumnStore
    [bool] $IsCapSystem
    [nullable[system.datetimeoffset]] $LastModifiedTimestamp
    [nullable[system.datetimeoffset]] $LastDeployedTimestamp
    [IndexField[]] $IndexFields
}
class IndexField {
    [int] $Id
    [int] $IndexId
    [nullable[int]] $FieldId
    [int] $Ordinal
    [bool] $IsDescending
    [bool] $IsCovering
}
class ObjectAttributeValue {
    [string] $AttributeName
    [string] $AttributeValue
}