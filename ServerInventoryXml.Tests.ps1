Import-Module "$PSScriptRoot\ServerInventoryXml.psm1"

#Note: TestDrive only works within a Describe or Context Block so we wont use it here
if(!(Test-Path "$PSScriptRoot\Temp")) {
    New-Item -ItemType directory -Path "$PSScriptRoot\Temp"
}
$Global:ReferencePath = "$PSScriptRoot\Temp\reference.xml"
$Global:DifferencePath = "$PSScriptRoot\Temp\difference.xml"
$Global:RubbishPath = "$PSScriptRoot\Temp\rubbish.txt"

#Create our reference xml file
$xmlWriter = New-Object System.XMl.XmlTextWriter($ReferencePath,$Null)
$xmlWriter.Formatting = 'Indented'
$xmlWriter.Indentation = 1
$XmlWriter.IndentChar = "`t"
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement('Server')
$XmlWriter.WriteAttributeString('Hostname', $env:COMPUTERNAME)
$xmlWriter.WriteStartElement('InstalledSoftware')
$xmlWriter.WriteStartElement('Application')
$xmlWriter.WriteAttributeString('Name', 'Microsoft Word')
$xmlWriter.WriteElementString('Version', '1.0.1')
$xmlWriter.WriteElementString('InstallLocation', 'C:\Program Files\Office\Word')
$xmlWriter.WriteEndElement()
$xmlWriter.WriteStartElement('Application')
$xmlWriter.WriteAttributeString('Name', 'Apache James')
$xmlWriter.WriteElementString('Version', '2.3.2')
$xmlWriter.WriteElementString('InstallLocation', 'C:\Program Files (x86)\james2.3.2')
$xmlWriter.WriteEndElement()
$xmlWriter.WriteStartElement('Application')
$xmlWriter.WriteAttributeString('Name', '7-zip')
$xmlWriter.WriteElementString('Version', '2.3.4')
$xmlWriter.WriteElementString('InstallLocation', 'C:\Program Files (x86)\7-zip')
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()

#Create our difference xml file
$xmlWriter = New-Object System.XMl.XmlTextWriter($DifferencePath,$Null)
$xmlWriter.Formatting = 'Indented'
$xmlWriter.Indentation = 1
$XmlWriter.IndentChar = "`t"
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement('Server')
$XmlWriter.WriteAttributeString('Hostname', $env:COMPUTERNAME)
$xmlWriter.WriteStartElement('InstalledSoftware')
$xmlWriter.WriteStartElement('Application')
$xmlWriter.WriteAttributeString('Name', 'Microsoft Word')
$xmlWriter.WriteElementString('Version', '1.0.1')
$xmlWriter.WriteElementString('InstallLocation', 'C:\Program Files\Office\Word')
$xmlWriter.WriteEndElement()
$xmlWriter.WriteStartElement('Application')
$xmlWriter.WriteAttributeString('Name', 'Apache James')
$xmlWriter.WriteElementString('Version', '2.3.4')
$xmlWriter.WriteElementString('InstallLocation', 'C:\Program Files (x86)\james2.3.4')
$xmlWriter.WriteEndElement()
$xmlWriter.WriteStartElement('Application')
$xmlWriter.WriteAttributeString('Name', 'Apache Tomcat')
$xmlWriter.WriteElementString('Version', '8.0.36')
$xmlWriter.WriteElementString('InstallLocation', 'C:\Program Files\Apache Software Foundation\Tomcat 8')
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()

#Create our non-xml file
Set-Content $RubbishPath -value "my test text."

Describe "Get-ApplicationFriendlyName" {
    InModuleScope ServerInventoryXml {
        It "given an application name that includes a version number at the end should return just the name" {
            Get-ApplicationFriendlyName -Name "Apache James 2.3.4" -Version "2.3.4"| Should Be "Apache James"
        }
        It "given an application name that includes a number in it should return its name" {
            Get-ApplicationFriendlyName -Name "7-zip" -Version "1.0" | Should Be "7-zip"
        }
        It "given an application name that includes a number in it and a version number should return its name" {
            Get-ApplicationFriendlyName -Name "7-zip 1.0" -Version "1.0" | Should Be "7-zip"
        }
        It "accepts named input from the pipeline" {
            $test = New-Object PSObject
            Add-Member -InputObject $test -MemberType NoteProperty -Name "Name" -Value "Apache James 2.3.2"
            Add-Member -InputObject $test -MemberType NoteProperty -Name "Version" -Value "2.3.2"
            $test1 = New-Object PSObject
            Add-Member -InputObject $test1 -MemberType NoteProperty -Name "Name" -Value "Apache Tomcat 8.0.36"
            Add-Member -InputObject $test1 -MemberType NoteProperty -Name "Version" -Value "8.0.36"
            $test,$test1 | Get-ApplicationFriendlyName | Should Be @("Apache James","Apache Tomcat")
        }
    }
}

Describe "Get-XmlElement" {
    InModuleScope ServerInventoryXml {
        It "given an element path it cant find should be null" {
            Get-XmlElement -Path $ReferencePath -Element "Server.InstalledSoftware.Banana" | Should BeNullOrEmpty
        }
        It "given an non-xml input should THROW" {
            { Get-XmlElement -Path $RubbishPath -Element "Server.InstalledSoftware.Application" } | Should Throw
        }
        It "given a filter it cant find should be null" {
            Get-XmlElement -Path $ReferencePath -Element "Server.InstalledSoftware.Application" -FilterProp "Name" -FilterValue "Microsoft Powerpoint" | Should BeNullOrEmpty
        }
        It "given a path it cant find should THROW" {
            { Get-XmlElement -Path "C:\test\test.xml" -Element "Server.InstalledSoftware.Application" } | Should Throw
        }
        It "given a valid path and element should return an object" {
            Get-XmlElement -Path $ReferencePath -Element "Server.InstalledSoftware.Application" | Should Not BeNullOrEmpty
        }
        It "given a valid filter key/value should return the xml object" {
            (Get-XmlElement -Path $ReferencePath -Element "Server.InstalledSoftware.Application" -FilterProp "Name" -FilterValue "Microsoft Word").Version | Should Be "1.0.1"
        }
        It "should accept the path parameter from the pipeline" {
            ($ReferencePath | Get-XmlElement -Element "Server.InstalledSoftware.Application" -FilterProp "Name" -FilterValue "Microsoft Word").Version | Should Be "1.0.1"
        }
    }
}

Describe "Compare-Property" {
    InModuleScope ServerInventoryXml {
        It "given an invalid reference xml should THROW" {
            { Compare-Property -ReferenceObject $RubbishPath -DifferenceObject $DifferencePath -Name "Microsoft Word" -Property "Version" } | Should Throw
        }
        It "given an invalid difference xml should THROW" {
            { Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $RubbishPath -Name "Microsoft Word" -Property "Version"  } | Should Throw
        }
        It "given an unmatched property should THROW" {
            { Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath -Name "Microsoft Excel" -Property "Version"  } | Should Throw
        }
        It "given 2 identical xml files, should return matches is TRUE" {
            (Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $ReferencePath -Name "Microsoft Word" -Property "Version" ).Matches | Should Be $true
        }
        It "given different application versions, should return matches is FALSE" {
            (Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath -Name "Apache James" -Property "Version" ).Matches | Should Be $false
        }
        It "given matching application versions, should return matches is TRUE" {
            (Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath -Name "Microsoft Word" -Property "Version" ).Matches | Should Be $true
        }
        It "given different application install locations, should return matches is FALSE" {
            (Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath -Name "Apache James" -Property "InstallLocation" ).Matches | Should Be $false
        }
        It "given matching application install locations, should return matches is TRUE" {
            (Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath -Name "Microsoft Word" -Property "InstallLocation" ).Matches | Should Be $true
        }
        It "given a missing application, should return matches is FALSE" {
            (Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath -Name "7-zip" -Property "Name" ).Matches | Should Be $false
        }
        It "given application present in both, should return matches is TRUE" {
            (Compare-Property -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath -Name "Microsoft Word" -Property "Name" ).Matches | Should Be $true
        }
        It "given a reference path it cant find should THROW" {
            { Compare-Property -ReferenceObject "C:\test\test.xml" -DifferenceObject $DifferencePath -Name "Microsoft Word" -Property "Version" } | Should Throw
        }
        It "given a difference path it cant find should THROW" {
            { Compare-Property -ReferenceObject $ReferencePath -DifferenceObject "C:\test\test.xml" -Name "Microsoft Word" -Property "Version" } | Should Throw
        }
    }
}

Describe "Get-DistictApplications" {
    InModuleScope ServerInventoryXml {
        It "given two input files containing some duplication should strip out the duplicates" {
            Get-DistinctApplications -ReferenceObject $ReferencePath -DifferenceObject $DifferencePath | Should Be @("Microsoft Word","Apache James","7-zip","Apache Tomcat")
        }
        It "given a reference path it cant find should THROW" {
            { Get-DistinctApplications -ReferenceObject "C:\test\test.xml" -DifferenceObject $DifferencePath } | Should Throw
        }
        It "given a difference path it cant find should THROW" {
            { Get-DistinctApplications -ReferenceObject $ReferencePath -DifferenceObject "C:\test\test.xml" } | Should Throw
        }
        It "given an invalid reference xml should THROW" {
            { Get-DistinctApplications -ReferenceObject $RubbishPath -DifferenceObject $DifferencePath } | Should Throw
        }
        It "given an invalid difference xml should THROW" {
            { Get-DistinctApplications -ReferenceObject $ReferencePath -DifferenceObject $RubbishPath } | Should Throw
        }
    }
}

#Tidy up our temp files
Remove-Item "$PSScriptRoot\Temp\*" -Force