@{
    AppName = 'QCacheGrind'
    Publisher = 'Kenneth Sills'
    PublisherEmail = 'ksills.dev@gmail.com'

    CraftRoot = 'C:\CraftRoot'
    CraftPackages = @(
        'kcachegrind'
    )

    BuiltExePath = 'build\kde\kdesdk\kcachegrind\work\build\bin\qcachegrind.exe'
    IconPath = 'build\kde\kdesdk\kcachegrind\work\build\kcachegrind\kcachegrind.ico'
    VersionHeaderPath = 'build\kde\kdesdk\kcachegrind\work\build\version.h'
    CMakeCachePath = 'build\kde\kdesdk\kcachegrind\work\build\CMakeCache.txt'

    GraphvizBin = 'C:\Program Files\Graphviz\bin'
    VsWhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    InnoCompiler = 'ISCC.exe'
    RcEdit = 'rcedit.exe'

    DistDir = 'dist\qcachegrind-win64'
    OutputDir = 'dist'
    IssTemplatePath = 'config\QCacheGrind.iss.template'
    IssOutputPath = 'dist\QCacheGrind.iss'

    ExtraDlls = @(
        'pcre2-16.dll'
        'zstd.dll'
        'b2-1.dll'
    )

    GraphvizRoots = @(
        'dot.exe'
        'gvplugin_*.dll'
    )

    InstallerBaseName = 'QCacheGrind-Setup'
    InstallerAppId = '{{286E7ED0-EF14-4ACB-AE38-86CDAC21695C}}'
}
