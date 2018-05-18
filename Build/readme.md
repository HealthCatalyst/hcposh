# **HCPosh** "documentation"
---

> **HCPosh** is a powershell module that provides some useful functions and tools when working with data in the Health Catalyst Analytics Platform.

Some key features include:

* built-in column-level **sql parser**, developed using the Microsoft.SqlServer.TransactSql.ScriptDom library.
* integration of **Graphviz** software for ERD and Data flow diagram generation (pdf, png, and svg)
* splits SAM Designer files into smaller files for source control

## installing HCPosh
1. after downloading or cloning this repo, double-click on the `HCPosh.msi` file found in the "Build" directory, which will install hcpsoh as a new powershell module on your user profile

## getting data from SAM Designer (SAMD) .hcx files
> using powershell, navigate to the folder where your hcx file lives (example cd .\Desktop\Folder\ )
then run some of the following commands:

return a metadata_raw.json and metadata_new.json, then splits these objects into a folder structure of content for easier source control management of SAMD data models.

* `HCPosh -Data`
   
output the hcx objects to a variable in-memory

* `$var = HCPosh -Data -OutVariable`
   
other options when using the `-Data` function

* `HCPosh -Data -Force`
* `HCPosh -Data -NoSplit`
* `HCPosh -Data -Raw`

## using the sql parser

getting tables and columns from sql queries

* `$var = HCPosh -SqlParser -Query "select wins from utah.jazz.basketball"`
   
optional enhancements that can be used with the parser

* `$var = HCPosh -SqlParser -Query "select wins from utah.jazz.basketball" -Log -SelectStar -Brackets`

## running an impact analysis using the sql parser
> using powershell, navigate to the folder where you want the output of the impact analysis to be saved to
then run some of the following commands:

creating the necessary config files

* `HCPosh -Impact -Server <My-Server>`
* this will prompt you to create some template files
   
running the impact analysis

* `HCPosh -Impact -Server <My-Server>`
* `HCPosh -Impact -Server <My-Server> -ConfigPath <Optional-Path> -OutDirectory <Optional-Path>`