﻿
<#
    .SYNOPSIS
        Get public OData Data Entity and their metadata
        
    .DESCRIPTION
        Get a list with all the public available OData Data Entities,and their metadata, that are exposed through the OData endpoint of the Dynamics 365 Finance & Operations environment
        
        The cmdlet will search across the singular names for the Data Entities and across the collection names (plural)
        
    .PARAMETER EntityName
        Name of the Data Entity you are searching for
        
        The parameter is Case Insensitive, to make it easier for the user to locate the correct Data Entity
        
    .PARAMETER EntityNameContains
        Name of the Data Entity you are searching for, but instructing the cmdlet to use search logic
        
        Using this parameter enables you to supply only a portion of the name for the entity you are looking for, and still a valid result back
        
        The parameter is Case Insensitive, to make it easier for the user to locate the correct Data Entity
        
    .PARAMETER ODataQuery
        Valid OData query string that you want to pass onto the D365 OData endpoint while retrieving data
        
        Important note:
        If you are using -EntityName or -EntityNameContains along with the -ODataQuery, you need to understand that the "$filter" query is already started. Then you need to start with -ODataQuery ' and XYZ eq XYZ', e.g. -ODataQuery ' and IsReadOnly eq false'
        If you are using the -ODataQuery alone, you need to start the OData Query string correctly. -ODataQuery '$filter=IsReadOnly eq false'
        
        OData specific query options are:
        $filter
        $expand
        $select
        $orderby
        $top
        $skip
        
        Each option has different characteristics, which is well documented at: http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part2-url-conventions.html
        
    .PARAMETER Tenant
        Azure Active Directory (AAD) tenant id (Guid) that the D365FO environment is connected to, that you want to access through OData
        
    .PARAMETER Url
        URL / URI for the D365FO environment you want to access through OData
        
    .PARAMETER ClientId
        The ClientId obtained from the Azure Portal when you created a Registered Application
        
    .PARAMETER ClientSecret
        The ClientSecret obtained from the Azure Portal when you created a Registered Application
        
    .PARAMETER EnableException
        This parameters disables user-friendly warnings and enables the throwing of exceptions
        This is less user friendly, but allows catching exceptions in calling scripts
        
    .EXAMPLE
        PS C:\> Get-D365ODataPublicEntity -EntityName customersv3
        
        This will get Data Entities from the OData endpoint.
        This will search for the Data Entities that are named "customersv3".
        
    .EXAMPLE
        PS C:\> (Get-D365ODataPublicEntity -EntityName customersv3).Value
        
        This will get Data Entities from the OData endpoint.
        This will search for the Data Entities that are named "customersv3".
        This will output the content of the "Value" property directly and list all found Data Entities and their metadata.
        
    .EXAMPLE
        PS C:\> Get-D365ODataPublicEntity -EntityNameContains customers
        
        This will get Data Entities from the OData endpoint.
        It will use the search string "customers" to search for any entity in their singular & plural name contains that search term.
        
    .EXAMPLE
        PS C:\> Get-D365ODataPublicEntity -EntityNameContains customer -ODataQuery ' and IsReadOnly eq true'
        
        This will get Data Entities from the OData endpoint.
        It will use the search string "customer" to search for any entity in their singular & plural name contains that search term.
        It will utilize the OData Query capabilities to filter for Data Entities that are "IsReadOnly = $true".
        
    .NOTES
        The OData standard is using the $ (dollar sign) for many functions and features, which in PowerShell is normally used for variables.
        
        Whenever you want to use the different query options, you need to take the $ sign and single quotes into consideration.
        
        Example of an execution where I want the top 1 result only, from a specific legal entity / company.
        This example is using single quotes, to help PowerShell not trying to convert the $ into a variable.
        Because the OData standard is using single quotes as text qualifiers, we need to escape them with multiple single quotes.
        
        -ODataQuery '$top=1&$filter=dataAreaId eq ''Comp1'''
        
        Tags: OData, Data, Entity, Query
        
        Author: Mötz Jensen (@Splaxi)
        
#>

function Get-D365ODataPublicEntity {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType()]
    param (

        [Parameter(Mandatory = $false, ParameterSetName = "Default")]
        [string] $EntityName,

        [Parameter(Mandatory = $true, ParameterSetName = "NameContains")]
        [string] $EntityNameContains,

        [Parameter(Mandatory = $false, ParameterSetName = "Default")]
        [Parameter(Mandatory = $false, ParameterSetName = "NameContains")]
        [Parameter(Mandatory = $true, ParameterSetName = "Query")]
        [string] $ODataQuery,

        [Parameter(Mandatory = $false)]
        [Alias('$AADGuid')]
        [string] $Tenant = $Script:ODataTenant,

        [Parameter(Mandatory = $false)]
        [Alias('URI')]
        [string] $URL = $Script:ODataUrl,

        [Parameter(Mandatory = $false)]
        [string] $ClientId = $Script:ODataClientId,

        [Parameter(Mandatory = $false)]
        [string] $ClientSecret = $Script:ODataClientSecret,

        [switch] $EnableException

    )


    begin {
        
        $bearerParms = @{
            Resource     = $URL
            ClientId     = $ClientId
            ClientSecret = $ClientSecret
        }

        $bearerParms.AuthProviderUri = "https://login.microsoftonline.com/$Tenant/oauth2/token"

        $bearer = Invoke-ClientCredentialsGrant @bearerParms | Get-BearerToken

        $headerParms = @{
            URL         = $URL
            BearerToken = $bearer
        }

        $headers = New-AuthorizationHeaderBearerToken @headerParms

        [System.UriBuilder] $odataEndpoint = $URL
        $odataEndpoint.Path = "metadata/PublicEntities"
    }

    process {
        $odataEndpoint.Query = ""
        
        if (-not ([string]::IsNullOrEmpty($EntityName))) {
            $searchEntityName = $EntityName
            $odataEndpoint.Query = "`$filter=(tolower(Name) eq tolower('$EntityName') or tolower(EntitySetName) eq tolower('$EntityName'))"
        }
        elseif (-not ([string]::IsNullOrEmpty($EntityNameContains))) {
            $searchEntityName = $EntityNameContains
            $odataEndpoint.Query = "`$filter=(contains(tolower(Name), tolower('$EntityNameContains')) or contains(tolower(EntitySetName), tolower('$EntityNameContains')))"
        }

        if (-not ([string]::IsNullOrEmpty($ODataQuery))) {
            $odataEndpoint.Query = $($odataEndpoint.Query + "$ODataQuery").Replace("?", "")
        }

        try {
            Write-PSFMessage -Level Verbose -Message "Executing http request against the OData endpoint." -Target $($odataEndpoint.Uri.AbsoluteUri)
            Invoke-RestMethod -Method Get -Uri $odataEndpoint.Uri.AbsoluteUri -Headers $headers -ContentType 'application/json'
        }
        catch {
            $messageString = "Something went wrong while searching for the entity: $searchEntityName"
            Write-PSFMessage -Level Host -Message $messageString -Exception $PSItem.Exception -Target $entityName
            Stop-PSFFunction -Message "Stopping because of errors." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>',''))) -ErrorRecord $_
            return
        }
    }
}