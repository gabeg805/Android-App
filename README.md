# Android Development Tutorial

## Introduction

This document is meant to outline how to develop an Android app without having
to use Android Studio.

All packages that should be installed are under *pkg/* and any code or other
files used in the development process will be under *dev/*.

When building an app, run the *android-app.sh* script.

## Android App Script

In the following examples *\<app-name\>* will indicate the name of your app,
e.g. NameOfApp, and *\<avd\>* will indicate the name of the Android Virtual
Device.

The AVD is determined automatically, as a result, using the AVD option is
optional. It is determined automatically, by the command:
```
emulator -list-avds | sort | head -1
```

If you are interested in specifying your own AVD, simply run the first command.
```
emulator -list-avds
```

### Execute all actions.

Build the app, run the emulator, install the app, and run the app.
```
android-app.sh -a -n <app-name>
```

### Build a package.

```
android-app.sh -b -n <app-name>
```

### Run the Android Emulator.

```
android-app.sh -e -d <avd>
```

### Install a package.

```
android-app.sh -i -n <app-name>
```

### Uninstall a package.

```
android-app.sh -u -n <app-name>
```

### Run an app.

```
android-app.sh -r -n <app-name>
```

### Kill the Android Emulator.

```
android-app.sh -k
```
