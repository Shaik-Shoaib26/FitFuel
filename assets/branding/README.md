# FitFuel identity artwork handoff

No approved custom mark or wordmark artwork is currently bundled. Web launcher icons still display the Flutter template; native launch backgrounds have template configuration. These are not final FitFuel branding.

Supply an approved vector master mark and wordmark, light/dark monochrome variants, a 1024px square store-icon master, and maskable web exports with the required safe area. Export Android adaptive-icon foreground/background, iOS icon sizes, favicon and splash mark from that same approved source.

`FitFuelIdentity` accepts an `ImageProvider` for the mark and supports compact navigation usage. It currently renders the existing FitFuel name typographically, without pretending a generic icon is a logo. It can also be used in a Flutter splash composition; native splash assets must be exported separately.

Register the actual artwork files in pubspec.yaml after they are supplied. This folder deliberately contains no fabricated images or nonexistent asset references.
