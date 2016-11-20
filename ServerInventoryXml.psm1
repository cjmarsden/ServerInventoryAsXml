##-------------------------------------------------
##------------Inventorying Functions---------------
##-------------------------------------------------

function Get-ServerInventoryAsXml {
    <#
        .SYNOPSIS
            Create a server inventory and output as an XML file
        .PARAMETER Path
            [string] [mandatory] Path to out-file
        .PARAMETER Applications
            [switch] Include installed applications in the inventory
        .EXAMPLE
            To create a server inventory for installed applications and output the result to \path\to\output\file.xml: 
            Get-ServerInventoryAsXml -Path \path\to\output\file.xml -Applications
    #>
    [CmdletBinding()]
    param(

        [Parameter(Mandatory=$true)]
        [string] $Path,

        [Parameter(Mandatory=$false)]
        [switch] $Applications

    )

    #Setup our xml file
    $xmlWriter = New-Object System.Xml.XmlTextWriter($Path,$Null)
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $XmlWriter.IndentChar = "`t"
    $xmlWriter.WriteStartDocument()
    $xmlWriter.WriteStartElement('Server')
    $XmlWriter.WriteAttributeString('Hostname', $env:COMPUTERNAME)

    if($Applications) {

        $xmlWriter.WriteStartElement('InstalledSoftware')

        #Obtain the installed software from the registry and add the key info to the xml object
        Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Where-Object { (Get-ItemProperty Microsoft.PowerShell.Core\Registry::$_).DisplayName -ne $null } | ForEach-object {
   
            $prop = Get-ItemProperty Microsoft.PowerShell.Core\Registry::$_

            #Some applications include the version number in their name which is unhelpful when comparing confiugrations, so strip the number out of the name
            $AppVersion = $prop.DisplayVersion
            if($AppVersion) {
                $FriendlyName = Get-ApplicationFriendlyName -Name $prop.DisplayName -Version $AppVersion
            }

            $xmlWriter.WriteStartElement('Application')
            $xmlWriter.WriteAttributeString('Name', $FriendlyName)
            $xmlWriter.WriteElementString('Version', $AppVersion)
            $xmlWriter.WriteElementString('InstallLocation', $prop.InstallLocation)
            $xmlWriter.WriteEndElement()

        }

        $xmlWriter.WriteEndElement()

    }

    $xmlWriter.WriteEndElement()

    #Finalise our xml document and write to file
    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()

}

function Get-InventoryDeltas {
    <#
        .SYNOPSIS
            Find differences between two server inventories and output this as an XML file
        .PARAMETER Path
            [string] [mandatory] Path to out-file
        .PARAMETER ReferenceObject
            [string] [mandatory] [position 1] Path to reference XML file
        .PARAMETER DifferenceObject
            [string] [mandatory] [position 2] Path to reference XML file
        .EXAMPLE
            To find anomalies between two server inventories stored in \somepath\server1.xml and \somepath\server2.xml, and then output the result to \path\to\output\deltafile.xml:
            Get-InventoryDeltas -Path \path\to\output\deltafile.xml -ReferenceObject \somepath\server1.xml -DifferenceObject \somepath\server2.xml
    #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory=$true)]
        [string] $Path,

        [Parameter(Mandatory=$true, Position=1)]
        [ValidateScript({Test-Path $_})]
        [string] $ReferenceObject,

        [Parameter(Mandatory=$true, Position=2)]
        [ValidateScript({Test-Path $_})]
        [string] $DifferenceObject
    )

    #Get the hostnames from each inventory
    $ReferenceServerName = (Get-XmlElement -Path $ReferenceObject -Element "Server").Hostname
    $DifferenceServerName = (Get-XmlElement -Path $DifferenceObject -Element "Server").Hostname

    #Setup our xml file
    $xmlWriter = New-Object System.Xml.XmlTextWriter($Path,$Null)
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $XmlWriter.IndentChar = "`t"
    $xmlWriter.WriteStartDocument()
    $xmlWriter.WriteStartElement('Deltas')
    $XmlWriter.WriteAttributeString('Server1', $ReferenceServerName)
    $XmlWriter.WriteAttributeString('Server2', $DifferenceServerName)

    $xmlWriter.WriteStartElement('Applications')
    
    #Get a list of all the applications installed in both inventories then loop through them
    Get-DistinctApplications -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject | ForEach-Object {

        $AppName = $_

        $DeltaName = Compare-Property -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Name $AppName -Property "Name"
        $DeltaVersion = Compare-Property -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Name $AppName -Property "Version"
        $DeltaLocation = Compare-Property -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Name $AppName -Property "InstallLocation"

        #If a particular element is an exact match in both inventories then skip it and move to the next application, otherwise write out the differences
        if(!(($DeltaName.Matches -eq $true) -and ($DeltaVersion.Matches -eq $true) -and ($DeltaLocation.Matches -eq $true))) {
            $xmlWriter.WriteStartElement('Application')
            $xmlWriter.WriteAttributeString('Name', $AppName)
            $xmlWriter.WriteStartElement('Present')
            $xmlWriter.WriteElementString('Server1', [string]::IsNullOrEmpty($DeltaName.ReferenceName))
            $xmlWriter.WriteElementString('Server2', [string]::IsNullOrEmpty($DeltaName.DifferenceName))
            $xmlWriter.WriteEndElement()

            if($DeltaVersion.Matches -ne $true){
                $xmlWriter.WriteStartElement('Version')
                $xmlWriter.WriteElementString('Server1', $DeltaVersion.ReferenceVersion)
                $xmlWriter.WriteElementString('Server2', $DeltaVersion.DifferenceVersion)
                $xmlWriter.WriteEndElement()
            }
            if($DeltaLocation.Matches -ne $true){
                $xmlWriter.WriteStartElement('InstallLocation')
                $xmlWriter.WriteElementString('Server1', $DeltaLocation.ReferenceInstallLocation)
                $xmlWriter.WriteElementString('Server2', $DeltaLocation.DifferenceInstallLocation)
                $xmlWriter.WriteEndElement()
            }
            $xmlWriter.WriteEndElement()
        }

    }
    
    $xmlWriter.WriteEndElement()

    #Finalise our xml document and write to file
    $xmlWriter.WriteEndElement()
    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()
}

##-------------------------------------------
##------------Helper Functions---------------
##-------------------------------------------

function Get-XmlElement {
    <#
        .SYNOPSIS
            Function to navigate through an XML element to find a given property for an element string
        .PARAMETER Path
            [string] [mandatory] [position 1] Path to input xml document
        .PARAMETER Element
            [string] [mandatory] Location of element
        .PARAMETER FilterProp
            [string] [mandatory] Property key to filter by
        .PARAMETER FilterValue
            [string] [mandatory] Property value to filter by
        .OUTPUTS
            [xml] object result of the searched element
        .EXAMPLE
            To get the xml element described by Server.InstalledSoftware.Applications.Name = "Microsoft Word"
            Get-XmlElement -Path \path\to\output\file.xml -Element "Server.InstalledSoftware.Applications" -FilterProp "Name" -FilterValue "Microsoft Word"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=1)]
        [ValidateScript({Test-Path $_})]
        [string] $Path,

        [Parameter(Mandatory=$true)]
        [string] $Element,

        [Parameter(Mandatory=$false,ParameterSetName="Filter")]
        [string] $FilterProp,

        [Parameter(Mandatory=$false,ParameterSetName="Filter")]
        [string] $FilterValue
    )

    process {
        [xml]$XmlDocument = Get-Content -Path $Path
        $XmlElementArray = $Element.Split(".")
        $output = $XmlDocument
    
        #Recurse through the xml to the location specified by $Element
        foreach ($value in $XmlElementArray) {
            $Output = $output.$value
        }

        #Filter if requested
        if($FilterProp) {
            $Output = ( $Output | Where-Object { $_.$FilterProp -eq $FilterValue } )
        }

        $Output
    }

}

function Get-ApplicationFriendlyName {
    <#
        .SYNOPSIS
            Function to strip out the version number when included in the application name
        .PARAMETER Name
            [string] [mandatory] [position 1] Full application name
        .PARAMETER Version
            [string] [mandatory] [position 2] Application version
        .OUTPUTS
            [string] Application name without version number
        .EXAMPLE
            To get the base application name "Apache James" from "Apache James 2.3.2"
            Get-ApplicationFriendlyName -Name "Apache James 2.3.2" -Version "2.3.2"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        [string] $Name,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=2)]
        [string] $Version
    )

    process {
        #Strip out the version number if it exists in the name
        if($Name.Contains($Version)) {
            $Name = $Name -replace $Version,""
        }

        #Remove any trailing whitespace
        $Name.Trim()
    }

}

##-----------------------------------------------
##------------Comparison Functions---------------
##-----------------------------------------------

function Compare-Property {
    <#
        .SYNOPSIS
            Given two XML elements, compare the values of a given property
        .PARAMETER ReferenceObject
            [string] [mandatory] [position 1] Path to reference XML file
        .PARAMETER DifferenceObject
            [string] [mandatory] [position 2] Path to difference XML file
        .PARAMETER Name
            [string] [mandatory] Element to compare
        .PARAMETER Property
            [string] [mandatory] Property to compare (limited to supported elements)
        .OUTPUTS
            [xml] object containing value of reference and difference elements, and Matches (true/false)
        .EXAMPLE
            To compare the version of Microsoft Word in \somepath\server1.xml and \somepath\server2.xml
            Compare-Property -ReferenceObject \somepath\server1.xml -DifferenceObject \somepath\server2.xml -Name "Microsoft Word" -Property "Version"
    #>    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=1)]
        [ValidateScript({Test-Path $_})]
        [string] $ReferenceObject,

        [Parameter(Mandatory=$true, Position=2)]
        [ValidateScript({Test-Path $_})]
        [string] $DifferenceObject,

        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Name","Version","InstallLocation")]
        [string] $Property

    )

    $ReferenceApp = Get-XmlElement -Path $ReferenceObject -Element "Server.InstalledSoftware.Application" -FilterProp "Name" -FilterValue $Name
    $DifferenceApp = Get-XmlElement -Path $DifferenceObject -Element "Server.InstalledSoftware.Application" -FilterProp "Name" -FilterValue $Name

    #If both reference and difference are null we dont want to report a match so throw an error
    if(($ReferenceApp -eq $null) -and ($DifferenceApp -eq $null)) {
        Throw
    }

    $ReferenceAppProp = $ReferenceApp.$Property
    $DifferenceAppPRop = $DifferenceApp.$Property

    if($ReferenceAppProp -eq $DifferenceAppProp){
        $Matches = $true
    }
    else {
        $Matches = $false
    }

    #Create an object to return containing all the info
    $Output = New-Object PSObject
    Add-Member -InputObject $Output -MemberType NoteProperty -Name "Reference$Property" -Value $ReferenceAppProp
    Add-Member -InputObject $Output -MemberType NoteProperty -Name "Difference$Property" -Value $DifferenceAppProp
    Add-Member -InputObject $Output -MemberType NoteProperty -Name Matches -Value $Matches

    return $Output
}

function Get-DistinctApplications {
    <#
        .SYNOPSIS
            Create a list of distinct (i.e. no duplicates) applications on two hosts
        .PARAMETER ReferenceObject
            [string] [mandatory] [position 1] Path to reference XML file
        .PARAMETER DifferenceObject
            [string] [mandatory] [position 2] Path to difference XML file
        .OUTPUTS
            [array] List of distinct applications installed in both inventories
        .EXAMPLE
            To list distinct application in \somepath\server1.xml and \somepath\server2.xml
            Get-DistinctApplications -ReferenceObject \somepath\server1.xml -DifferenceObject \somepath\server2.xml
    #>  
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=1)]
        [ValidateScript({Test-Path $_})]
        [string] $ReferenceObject,

        [Parameter(Mandatory=$true, Position=2)]
        [ValidateScript({Test-Path $_})]
        [string] $DifferenceObject
    )

    $AppList = @()
    
    #Add all the applications for the first host
    Get-XmlElement -Path $ReferenceObject -Element "Server.InstalledSoftware.Application" | ForEach-Object { $AppList += $_.Name }

    #Only add applications from the second host if they're not already in the list
    Get-XmlElement -Path $DifferenceObject -Element "Server.InstalledSoftware.Application" | ForEach-Object { if($AppList -notcontains $_.Name) {$AppList += $_.Name} }

    return $AppList
}