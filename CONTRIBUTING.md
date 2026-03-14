# Contributing

Pull requests are always welcome!

## Pre-PR Checklist

Before submitting a PR, please make sure to run the lint script:

```powershell
.\Lint
```

This is really just a simple walkabout with
[PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer), which you'll
need
[to install separately](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules#installing-psscriptanalyzer).

When you think you're finished making changes, self-test through the following
checklist:

- [ ] The build script works with prerequisites installed.
- [ ] The generated setup executable works, and installs the application.
- [ ] The installed application has the expected publisher and version number
  *in Windows*.
- [ ] Running the application works.
- [ ] Call graphs generated with `dot` load from within the application.
- [ ] Uninstalling the application works.
