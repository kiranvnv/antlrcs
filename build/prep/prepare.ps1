param (
  [switch]$Debug,
  [string]$VisualStudioVersion = '15.0',
  [string]$Verbosity = 'minimal',
  [string]$Logger,
  [switch]$NoValidate
)

. .\version.ps1

# build the solution
$SolutionPath = "..\..\Antlr3.sln"

# make sure the script was run from the expected path
if (!(Test-Path $SolutionPath)) {
  $host.ui.WriteErrorLine("The script was run from an invalid working directory.")
  exit 1
}

If ($Debug) {
  $BuildConfig = 'Debug'
} Else {
  $BuildConfig = 'Release'
}

$DebugBuild = $false

# clean up from any previous builds
$CleanItems = "Runtime", "Tool", "Bootstrap", "ST3", "ST4"
$CleanItems | ForEach-Object {
  if (Test-Path $_) {
    Remove-Item -Force -Recurse $_
  }
}

# build the project
$visualStudio = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7')."$VisualStudioVersion"
$msbuild = "$visualStudio\MSBuild\$VisualStudioVersion\Bin\MSBuild.exe"
If (-not (Test-Path $msbuild)) {
  $host.UI.WriteErrorLine("Couldn't find MSBuild.exe")
  exit 1
}

If ($Logger) {
  $LoggerArgument = "/logger:$Logger"
}

# Make sure we don't have a stray config file from the bootstrap build
If (Test-Path '..\..\NuGet.config') {
  Remove-Item '..\..\NuGet.config'
}

# Restore packages
.\NuGet.exe update -self
.\NuGet.exe restore $SolutionPath -Project2ProjectTimeOut 1200

&$msbuild /nologo /m /nr:false /t:rebuild $LoggerArgument "/verbosity:$Verbosity" /p:Configuration=$BuildConfig $SolutionPath
If (-not $?) {
  $host.ui.WriteErrorLine("Build Failed, Aborting!")
  exit $LASTEXITCODE
}

# Build Antlr3.CodeGenerator so we can use it for the boostrap build
.\NuGet.exe pack .\Antlr3.CodeGenerator.nuspec -OutputDirectory nuget -Prop Configuration=$BuildConfig -Version $AntlrVersion -Prop ANTLRVersion=$AntlrVersion -Prop STVersion=$STVersion -Symbols
If (-not $?) {
  $host.ui.WriteErrorLine("Failed to create NuGet package prior to bootstrap, Aborting!")
  exit 1
}

# build the project again with the new bootstrap files
copy -force '..\..\NuGet.config.bootstrap' '..\..\NuGet.config'
.\NuGet.exe restore $SolutionPath -Project2ProjectTimeOut 1200
&$msbuild /nologo /m /nr:false /t:rebuild "/verbosity:$Verbosity" /p:Configuration=$BuildConfig $SolutionPath
If (-not $?) {
  $host.ui.WriteErrorLine("Build Failed, Aborting!")
  Remove-Item '..\..\NuGet.config'
  exit 1
}

Remove-Item '..\..\NuGet.config'

# copy files from the build
mkdir Runtime
mkdir Tool
mkdir Tool\Rules
mkdir Bootstrap
mkdir ST3
mkdir ST4
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.dll" ".\Runtime"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.pdb" ".\Runtime"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.xml" ".\Runtime"
copy "..\..\LICENSE.txt" ".\Runtime"

copy "..\..\bin\$BuildConfig\net35-client\Antlr3.exe" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.exe.config" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.dll" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.Debug.dll" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.dll" ".\Tool"
if ($DebugBuild) {
  copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.Visualizer.dll" ".\Tool"
}
copy "..\..\bin\$BuildConfig\net40\Antlr3.CodeGenerator.DefaultItems.props" ".\Tool"
copy "..\..\bin\$BuildConfig\net40\Antlr3.CodeGenerator.DefaultItems.targets" ".\Tool"
copy "..\..\bin\$BuildConfig\net40\Antlr3.CodeGenerator.props" ".\Tool"
copy "..\..\bin\$BuildConfig\net40\Antlr3.CodeGenerator.targets" ".\Tool"
copy "..\..\bin\$BuildConfig\net40\AntlrBuildTask.dll" ".\Tool"
copy "..\..\bin\$BuildConfig\net40\Rules\Antlr3.ProjectItemsSchema.xml" ".\Tool\Rules"
copy "..\..\bin\$BuildConfig\net40\Rules\Antlr3.xml" ".\Tool\Rules"
copy "..\..\bin\$BuildConfig\net40\Rules\AntlrAbstractGrammar.xml" ".\Tool\Rules"
copy "..\..\bin\$BuildConfig\net40\Rules\AntlrTokens.xml" ".\Tool\Rules"
copy "..\..\LICENSE.txt" ".\Tool"

copy ".\Tool\*" ".\Bootstrap"

# copy ST4 binaries and all symbol files to the full Tool folder
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.pdb" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.pdb" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.Debug.pdb" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.pdb" ".\Tool"
if ($DebugBuild) {
  copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.Visualizer.pdb" ".\Tool"
}
copy "..\..\bin\$BuildConfig\net40\AntlrBuildTask.pdb" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.xml" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.xml" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.Debug.xml" ".\Tool"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.xml" ".\Tool"
if ($DebugBuild) {
  copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.Visualizer.xml" ".\Tool"
}
copy "..\..\bin\$BuildConfig\net40\AntlrBuildTask.xml" ".\Tool"

mkdir "Tool\Codegen"
mkdir "Tool\Targets"
mkdir "Tool\Tool"
copy -r "..\..\bin\$BuildConfig\net35-client\Codegen\*" ".\Tool\Codegen"
copy -r "..\..\bin\$BuildConfig\net35-client\Targets\*.dll" ".\Tool\Targets"
copy -r "..\..\bin\$BuildConfig\net35-client\Targets\*.pdb" ".\Tool\Targets"
copy -r "..\..\bin\$BuildConfig\net35-client\Targets\*.xml" ".\Tool\Targets"
copy -r "..\..\bin\$BuildConfig\net35-client\Tool\*" ".\Tool\Tool"

mkdir "Bootstrap\Codegen\Templates\CSharp2"
mkdir "Bootstrap\Codegen\Templates\CSharp3"
mkdir "Bootstrap\Tool"
mkdir "Bootstrap\Targets"
copy "..\..\bin\$BuildConfig\net35-client\Codegen\Templates\LeftRecursiveRules.stg" ".\Bootstrap\Codegen\Templates"
copy "..\..\bin\$BuildConfig\net35-client\Codegen\Templates\CSharp2\*" ".\Bootstrap\Codegen\Templates\CSharp2"
copy "..\..\bin\$BuildConfig\net35-client\Codegen\Templates\CSharp3\*" ".\Bootstrap\Codegen\Templates\CSharp3"
copy "..\..\bin\$BuildConfig\net35-client\Targets\Antlr3.Targets.CSharp2.dll" ".\Bootstrap\Targets"
copy "..\..\bin\$BuildConfig\net35-client\Targets\Antlr3.Targets.CSharp3.dll" ".\Bootstrap\Targets"
copy -r "..\..\bin\$BuildConfig\net35-client\Tool\*" ".\Bootstrap\Tool"
Remove-Item ".\Bootstrap\Tool\Templates\messages\formats\gnu.stg"

# ST3 dist
copy "..\..\Antlr3.StringTemplate\bin\$BuildConfig\net35-client\Antlr3.StringTemplate.dll" ".\ST3"
copy "..\..\Antlr3.StringTemplate\bin\$BuildConfig\net35-client\Antlr3.Runtime.dll" ".\ST3"
copy "..\..\Antlr3.StringTemplate\bin\$BuildConfig\net35-client\Antlr3.StringTemplate.pdb" ".\ST3"
copy "..\..\Antlr3.StringTemplate\bin\$BuildConfig\net35-client\Antlr3.Runtime.pdb" ".\ST3"
copy "..\..\Antlr3.StringTemplate\bin\$BuildConfig\net35-client\Antlr3.StringTemplate.xml" ".\ST3"
copy "..\..\Antlr3.StringTemplate\bin\$BuildConfig\net35-client\Antlr3.Runtime.xml" ".\ST3"
copy "..\..\LICENSE.txt" ".\ST3"

# ST4 dist
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.dll" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.dll" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.Visualizer.dll" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.pdb" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.pdb" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.Visualizer.pdb" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr3.Runtime.xml" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.xml" ".\ST4"
copy "..\..\bin\$BuildConfig\net35-client\Antlr4.StringTemplate.Visualizer.xml" ".\ST4"
copy "..\..\LICENSE.txt" ".\ST4"

# compress the distributable packages

$ArchivePath = ".\dist\antlr-dotnet-csharpbootstrap-" + $AntlrVersion + ".7z"
.\7z.exe a -r -mx9 $ArchivePath ".\Bootstrap\*"
$ArchivePath = ".\dist\antlr-dotnet-csharpruntime-" + $AntlrVersion + ".7z"
.\7z.exe a -r -mx9 $ArchivePath ".\Runtime\*"
$ArchivePath = ".\dist\antlr-dotnet-tool-" + $AntlrVersion + ".7z"
.\7z.exe a -r -mx9 $ArchivePath ".\Tool\*"
$ArchivePath = ".\dist\antlr-dotnet-st3-" + $AntlrVersion + ".7z"
.\7z.exe a -r -mx9 $ArchivePath ".\ST3\*"
$ArchivePath = ".\dist\antlr-dotnet-st4-" + $STVersion + ".7z"
.\7z.exe a -r -mx9 $ArchivePath ".\ST4\*"

# Build the NuGet packages

.\NuGet.exe pack .\Antlr3.CodeGenerator.nuspec -OutputDirectory nuget -Prop Configuration=$BuildConfig -Version $AntlrVersion -Prop ANTLRVersion=$AntlrVersion -Prop STVersion=$STVersion -Symbols
If (-not $?) {
  $host.ui.WriteErrorLine("Failed to create NuGet package, Aborting!")
  exit 1
}

.\NuGet.exe pack .\Antlr3.nuspec -OutputDirectory nuget -Prop Configuration=$BuildConfig -Version $AntlrVersion -Prop ANTLRVersion=$AntlrVersion -Prop STVersion=$STVersion -Symbols
If (-not $?) {
  $host.ui.WriteErrorLine("Failed to create NuGet package, Aborting!")
  exit 1
}

# Validate the build

If (-not $NoValidate) {
	git 'clean' '-dxf' '..\Validation'
	dotnet 'run' '--project' '..\Validation\DotnetValidation.csproj' '--framework' 'netcoreapp1.1'
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit $LASTEXITCODE
	}

	git 'clean' '-dxf' '..\Validation'
	.\NuGet.exe 'restore' '..\Validation'
	&$msbuild '/nologo' '/m' '/nr:false' '/t:Rebuild' $LoggerArgument "/verbosity:$Verbosity" "/p:Configuration=$BuildConfig" '..\Validation\DotnetValidation.sln'
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit 1
	}

	"..\Validation\bin\$BuildConfig\net20\DotnetValidation.exe"
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit 1
	}

	"..\Validation\bin\$BuildConfig\net30\DotnetValidation.exe"
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit 1
	}

	"..\Validation\bin\$BuildConfig\net35\DotnetValidation.exe"
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit 1
	}

	"..\Validation\bin\$BuildConfig\net40\DotnetValidation.exe"
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit 1
	}

	"..\Validation\bin\$BuildConfig\portable40-net40+sl5+win8+wp8+wpa81\DotnetValidation.exe"
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit 1
	}

	"..\Validation\bin\$BuildConfig\net45\DotnetValidation.exe"
	if (-not $?) {
		$host.ui.WriteErrorLine('Build failed, aborting!')
		Exit 1
	}
}
