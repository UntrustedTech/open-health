# Contributing to Health

Thanks for helping make Health better. A few rules keep the project's
licensing clean.

## License of contributions

Health's source code is available under the PolyForm Noncommercial License
1.0.0 ([LICENSE](LICENSE)). UntrustedTech also publishes official builds,
including paid features in the app stores, so before a contribution can be
merged you need to agree to the [Contributor License Agreement](CLA.md).
It lets UntrustedTech use your contribution in every edition of Health and
change the license later; you keep the copyright in your work.

To agree, add this line to your pull request's description:

    I have read and agree to the Health Contributor License Agreement (CLA.md).

## Don't contribute what isn't yours

- No code, images, fonts, data or text copied from elsewhere unless its
  license allows it to be used in Health, including in paid official
  builds (for example MIT, BSD, Apache-2.0 or the SIL Open Font License).
  Say where it came from and add its license to Acknowledgements.
- No health advice presented as medical fact; keep the app's wording
  "estimates" and "not medical advice".
- No trackers, analytics, ads or network calls that send user data
  anywhere.

## Before opening a pull request

```sh
flutter analyze
flutter test
```

Both must pass. Add tests for what you change.
