# Ilion

Ilion is (going to be) a localization helper tool for macOS that cuts the lengthy translate-build-verify loop by allowing for run-time localization adjustments.

### About the name

Ilion stands from i(nstant)-localization (l10n), but the name also makes reference to the ancient city of Troy, which the Greeks infiltrated by means of the famous Trojan Horse trick.

### What is it good for?

Ilion's purpose is to allow for near-live app localization on macOS. This means that localized strings can be added, removed, or changed run-time, without having to rebuild the project. In some cases, the app should be relaunched in order to see the changes, but sometimes not even that is necessary. Translators who have been suffering from lack of context can now have something real to play with. Checking whether the resizing behavior is properly configured for a text UI element or iterating on a translation until it fits-- all these can now be done with almost instant feedback using Ilion.

### How does it work

As of now, Ilion needs to be built into the target application and a minimal integration work is required. When the app is launched, the framework intercepts calls to NSLocalizedString and proxies them to a string database built from the `.strings` resources and the previously set overrides. This database can then be accessed and modified via the Ilion UI.

### Requirements

macOS 10.10

### Limitations

- only `.strings` files and UI base localization are supported (that is, one XIB + many strings files)
- changes are only preserved on the machine they have been made on
- changes cannot be exported or committed back to the original resources

### Planned improvements

- works out-of-the-box, eliminate most manual steps for integration
- export changes to file
- support for XLIFF files
- integration with cloud-based translation services

### License

MIT License