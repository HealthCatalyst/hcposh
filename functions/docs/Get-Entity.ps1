function Get-Entity ($ContentId) {
    return $DocsData.Entities[$DocsData.Entities.ContentId.IndexOf($ContentId)]
}
