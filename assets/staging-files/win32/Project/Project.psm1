# ----------------------------------------------------------------

# Get-ProjectPath -Path $Path
#
# Get the ancestor directory of $Path that contains a dune-project file.
function Get-ProjectDir {
    param (
        [Parameter(Mandatory = $true)]
        $Path
    )
    $AncestorPath = $Path
    while ($AncestorPath.Exists) {
        if (Test-Path -PathType Leaf `
                -Path (Join-Path -Path $AncestorPath.FullName -ChildPath "dune-project")) {
            Write-Output $AncestorPath
            return
        }
        $AncestorPath = $AncestorPath.Parent
    }
    throw "No dune-project was found in a parent, grandparent or other ancestor directory of $Path.`nThe script was meant to be called within a Diskuv OCaml (DKML) Local Project" `
}
Export-ModuleMember -Function Get-ProjectDir
