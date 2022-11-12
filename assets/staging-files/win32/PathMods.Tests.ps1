# Upgrade Pester to be >= 4.6.0 using Administrator PowerShell:
#   Install-Module -Name Pester -Force -SkipPublisherCheck

# In VSCode just click "Run tests" below

BeforeAll {
    $dsc = [System.IO.Path]::DirectorySeparatorChar
    if (Get-Module PathMods) {
        Write-Host "Removing old PathMods module from PowerShell session"
        Remove-Module PathMods
    }
    $env:PSModulePath += "$([System.IO.Path]::PathSeparator)${PSCommandPath}${dsc}.."
    Import-Module PathMods
}

Describe 'Join-EnvPathEntry' {
    It 'Always passes but displays the result of inserting opam\bin on this machine' {
        if ($Env:DiskuvOCamlHome) {
            $y = Join-EnvPathEntry `
                -PathValue ([Environment]::GetEnvironmentVariable("PATH", "User")) `
                -PathEntry $env:LOCALAPPDATA\Programs\opam\bin `
                -MustBeAfterEntryIfExists $Env:DiskuvOCamlHome\bin
            Write-Host "Effective PATH on this machine after Join-EnvPathEntry: $y"
        }
    }
    It 'Given empty PATH the new PATH will be the single entry' {
        $y = Join-EnvPathEntry -PathValue "" -PathEntry "C:\pester\item"
        $y | Should -Be "C:\pester\item"
    }
    It 'Given empty PATH with -MustBeAfterEntryIfExists the new PATH will be the single entry' {
        $y = Join-EnvPathEntry -PathValue "" -PathEntry "C:\pester\item" -MustBeAfterEntryIfExists "C:\pester\nonexistent"
        $y | Should -Be "C:\pester\item"
    }
    It 'Given single-item PATH with -MustBeAfterEntryIfExists that exists the new PATH will have the new entry last' {
        $y = Join-EnvPathEntry -PathValue "C:\pester\item" -PathEntry "C:\pester\anotheritem" -MustBeAfterEntryIfExists "C:\pester\item"
        $y | Should -Be "C:\pester\item;C:\pester\anotheritem"
    }
    It 'Given two-item PATH with -MustBeAfterEntryIfExists that exists as the first item, then the new PATH will have the new entry in the middle' {
        $y = Join-EnvPathEntry -PathValue "C:\pester\itemleft;C:\pester\itemright" -PathEntry "C:\pester\anotheritem" -MustBeAfterEntryIfExists "C:\pester\itemleft"
        $y | Should -Be "C:\pester\itemleft;C:\pester\anotheritem;C:\pester\itemright"
    }
    It 'Given five-item PATH with -MustBeAfterEntryIfExists that exists as the second item, then the new PATH will have the new entry in the middle' {
        $y = Join-EnvPathEntry `
            -PathValue "C:\pester\itemleft1;C:\pester\itemleft2;C:\pester\itemright1;C:\pester\itemright2" `
            -PathEntry "C:\pester\anotheritem" `
            -MustBeAfterEntryIfExists "C:\pester\itemleft2"
        $y | Should -Be "C:\pester\itemleft1;C:\pester\itemleft2;C:\pester\anotheritem;C:\pester\itemright1;C:\pester\itemright2"
    }
    It 'Given five-item PATH with -MustBeAfterEntryIfExists that exists as the second and third items, then the new PATH will have the new entry after the third' {
        $y = Join-EnvPathEntry `
            -PathValue "C:\pester\itemleft;C:\pester\itemsame;C:\pester\itemsame;C:\pester\itemright" `
            -PathEntry "C:\pester\anotheritem" `
            -MustBeAfterEntryIfExists "C:\pester\itemsame"
        $y | Should -Be "C:\pester\itemleft;C:\pester\itemsame;C:\pester\itemsame;C:\pester\anotheritem;C:\pester\itemright"
    }
    It 'Given five-item PATH with -MustBeAfterEntryIfExists that does not exist, then the new PATH will have the new entry first' {
        $y = Join-EnvPathEntry `
            -PathValue "C:\pester\itemleft1;C:\pester\itemleft2;C:\pester\itemright1;C:\pester\itemright2" `
            -PathEntry "C:\pester\anotheritem" `
            -MustBeAfterEntryIfExists "C:\pester\nonexistent"
        $y | Should -Be "C:\pester\anotheritem;C:\pester\itemleft1;C:\pester\itemleft2;C:\pester\itemright1;C:\pester\itemright2"
    }
}