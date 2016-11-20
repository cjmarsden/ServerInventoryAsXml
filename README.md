## Synopsis & Motivation

An extensible and scalable way of defining the state of a Windows Server instance and to be able to find differences between two instances.

Use cases:
- Describing the confugration of a server in a human and machine readable language.
- Describing configuration drift from a baseline;
- Needing to find divergence between two servers that should have identical configurations.

## Installation

To install on demand (e.g. as part of a script, or from the shell):

```powershell
Import-Module \path\to\ServerInventoryAsXml
```

To autoload with PowerShell, copy the module directory to `$env:windir\System32\WindowsPowerShell\v1.0\Modules`.

## Functions

- Inventory functions:
  - Get-ServerInventoryAsXml - Create a server inventory and output as an XML file;
  - Get-InventoryDeltas - Find differences between two server inventories and output this as an XML file.

- Comparison funtions
  - Compare-Property - Given two XML elements, compare the values of a given property;
  - Get-DistinctApplications - Create a list of distinct (i.e. no duplicates) applications on two hosts.

- Helper functions
  - Get-XmlElement - Function to navigate through an XML element to find a given property for an element string;
  - Get-ApplicationFriendlyName - Function to strip out the version number when included in the application name.

## Example

To create a server inventory for installed applications and output the result to \path\to\output\file.xml:

```powershell
Get-ServerInventoryAsXml -Path \path\to\output\file.xml -Applications
```

To find anomalies between two server inventories stored in \somepath\server1.xml and \somepath\server2.xml, and then output the result to \path\to\output\deltafile.xml:

```powershell
Get-InventoryDeltas -Path \path\to\output\deltafile.xml -ReferenceObject \somepath\server1.xml -DifferenceObject \somepath\server2.xml
```

## Tests

This project uses the [Pester] (https://github.com/pester/Pester) unit testing framework.

All tests are found in ServerInventoryXml.Tests.ps1 file. To run the tests ensure that Pester module is installed in the PowerShell modules directory, navigate to the project directory and run the command:

```powershell
Invoke-Pester
```

## Versions

#### 0.1.0

- Initial release with functionality for inventorying installed applications.

  - Inventory functions: Get-ServerInventoryAsXml; Get-InventoryDeltas.
  - Comparison funtions: Compare-Property; Get-DistinctApplications.
  - Helper functions: Get-XmlElement; Get-ApplicationFriendlyName.

## Roadmap

| Version | Planned functionality |
| --- | --- |
| 0.2.0 | Add ability to compare installed Windows Features |
| 0.3.0 | Add ability to compare installed Hotfixes and OS info |
| 0.4.0 | Add ability to compare users and groups |
| 0.5.0 | Add ability to compare networking |
| 0.6.0 | Add ability to compare shares, directories and permissions |

## Known Issues

None yet.

## License

The content of this project is licensed under the Apache License 2.0. More details are found in LICENSE.txt for full details, and <http://choosealicense.com/licenses/apache-2.0/>.