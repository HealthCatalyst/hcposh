# **HCPosh** "documentation"
---

> **HCPosh** is a Powershell module that provides some useful functions and tools when working with data in the Health Catalyst Analytics Platform.

Posh is short for "PowerShell", but is also an old sailor phrase of "Portside out, starboard home (P.O.S.H)"

## KEY FEATURES:

* Split SAM Designer hcx files into smaller files for source control using it's built-in column-level **SQL Parser**, developed using the **Microsoft.SqlServer.TransactSql.ScriptDom library**.
* Generate a React web application for **documentation** that contains **ERD and Data Flow Diagrams** for a professional look and presentation of a subject area mart
* Integration of Graphviz software for ERD and Data flow diagram generation (pdf, png, and svg)

## INSTALLATION
1. Download the HCPosh.msi in the build directory of this repository.
2. Double-click on the HCPosh.msi file to initiate the installation.
3. HCPosh requires you to change the execution policy from the default 'Restricted' to 'RemoteSigned':
    * Go to the Start Menu, Type in PowerShell, Right-Click and 'Run as Administrator'.
    * At the prompt, type in
    ```
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
    ```
    * Type in `A` for [A] Yes to All
4. Check the version of HCPosh with this powershell command
    ```
    HCPosh -Version
    ```

## GETTING DATA FROM SAMD HCX FILES FOR SOURCE CONTROL
* Using Powershell, navigate to the folder where your hcx file(s) live (example cd .\Desktop\Folder\ ) then run the following command:
    ```
    HCPosh -Data
    ```
* HCPosh will parse through the embedded json file and return a folder `_hcposh` with files that can be committed to source control with ease.

## GENERATING DOCUMENTATION FROM SAMD HCX FILES

* Using Powershell, navigate to the folder where your hcx file(s) live (example cd .\Desktop\Folder\ ) then run the following command:

    ```
    HCPosh -Docs
    ```
* HCPosh will extract the data, parsing the sql and identify the data lineage of your data mart and generate a static React web application with an `index.html` file that can be viewed in some of the latest browsers (**Chrome**, **Firefox**, **Edge** ... note that IE Explorer 11 can view the file however some features may look off)

## GENERATING DIAGRAM FILES (PDF, PNG, SVG)

* Using Powershell, navigate to the folder where your hcx file(s) live (example cd .\Desktop\Folder\ ) then run the following command:
    ```
    HCPosh -Diagrams
    ```

## USING THE SQL PARSER DIRECTLY

* Using Powershell, run the following command:
    ```
    HCPosh -SqlParser -Query "SELECT MyColumn FROM MyDatabase.MySchema.MyTable"
    ```
* This will directly use the sql parser to parse both tables and columns from a sql query.
