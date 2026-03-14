# Windows Build Script for QCacheGrind

A reproducible set of instructions for generating a QCacheGrind installer for
modern Windows.

Most people will just want to check out the Releases page for prebuilt binaries.
😊

> [!IMPORTANT]
> 
> I want to be upfront that this project was developed with the assistance of
> generative AI.
> 
> If this presents a moral or legal issue, you may need seek an alternative. I
> apologize for the trouble.

## FAQ

### What's a `.cgo` File?

The standard convention for callgrind and cachegrind files is to associate them
by a prefix - `callgrind.out*` or `cachegrind.out*` - and to place a
`#callgrind format` header line at the top of the file. Unfortunately, there's
no way to develop a file association for file content or file name prefixes in
Windows so you're forced to go into the program, open the load dialog, and find
your file that way.

This is just an unofficial file extension you can use for those
"**c**all**g**rind.**o**ut" files, to make working with them a tad more
ergonomic.

### How Do I Uninstall This?

Since we use a "real" installer, just go to your Windows Settings, then navigate
to "Apps" > "Installed Apps" and search for "QCacheGrind". Hit the triple dots,
then "Uninstall" like any other application!

### Why Is It So Big? 100 Mb!

Unicode. No, seriously, that alone is 50Mb of it.

It's not just a problem here, either. The [Bun](https://bun.com/) JS runtime has
a feature to
[build single-file executables](https://bun.com/docs/bundler/executables), where
despite shipping an entire Node runtime they're still left with half of a
resulting "Hello World" binary being
[`libicu`](https://github.com/oven-sh/bun/issues/2541#issuecomment-1494970956).

Unicode is a hard problem that requires big tables!

## Building Yourself

### Prerequisites

You will need to have manually installed all of the following before proceeding:

- [Visual Studio](https://visualstudio.microsoft.com/)
  - Install the `Desktop development with C++` workload.
  - The exact version needed for Craft may change. For Qt6 builds, use 2022
    (version 17).
- [KDE Craft](https://community.kde.org/Craft)
- [Python](https://www.python.org/downloads/)
- [Git for Windows](https://git-scm.com/download/win)
- [`rcedit`](https://github.com/electron/rcedit)
- [Graphviz](https://graphviz.org/download/)
- [Inno Setup](https://jrsoftware.org/isinfo.php)

### Usage

Once everything is set up, it should be simple. Just open a Craft shell and run
the build:

```powershell
.\Build
```

One complete, there should be an installer binary under `dist/`, easy peasy!

**Attribution:**

> [!important]
> 
> By distributing your own modified copies, you take on all licensing
> obligations for those copies, including at-request source distribution per
> GPL.

If you've made any changes or plan on publishing, update
`config/build-config.psd1` before building:

- Set `Publisher` to the name you want Windows to display.
- Set `PublisherEmail` to the contact address for written source requests.
- Set `InstallerAppId` to a new GUID if you're publishing your own fork or
  otherwise producing an installer that should not upgrade or conflict with the
  original package.

We do not currently have built-in support for application signing. PRs welcome,
but I have no way of testing it currently.

**Incremental Builds:**

For faster iteration on packaging-only changes, you can re-use the existing
Craft install instead of forcing a rebuild:

```powershell
.\Build -UseInstalled
```

### Troubleshooting

#### The Build Script Can't Find Required Dependencies

If you have any of the required tooling in non-standard locations you can update
most paths from inside `config/build-config.psd1`.

If any of those standard paths have changed, please open a ticket or PR!

#### The Build Paths Aren't Right

The script includes some assumptions about where files go and the hierarchy of
Craft. If any of those assumptions become outdated, please open a ticket or PR!
