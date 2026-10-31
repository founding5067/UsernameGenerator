# UsernameGenerator

A small, private username generator for iPhone, iPad, Mac and Apple Vision Pro.

Pick how many words, a separator, the capitalization, and whether to add digits. You get five options at once, like `QuietOtter4821` or `brave-falcon-07`. Tap one to copy it.

- **Themes:** animals, nature, space or food vocabularies.
- **Site rules:** cap the length (6–30) or allow letters and numbers only. If a limit is tight, digits and then words are dropped so every result fits.
- **Shortcuts, Siri and Spotlight:** a *Generate Username* action with all the same options.

## Privacy

- Everything runs on your device. No accounts, analytics, ads or network access.
- Generated usernames are never saved. Only your option choices are remembered.
- Randomness comes from `SystemRandomNumberGenerator`, the system's cryptographically secure source.

## Building

1. Open `UsernameGenerator.xcodeproj` in Xcode 27 or newer.
2. Select the **UsernameGenerator** target → **Signing & Capabilities** → choose your own Team.
3. Pick a device or simulator (or *My Mac*) and press Run.

Run the tests with ⌘U.

## Word filter

The EFF list was made for passwords, which nobody else sees, so it includes words you wouldn't want in a public username (crude, violent, medical, religious and so on). [`UsernameGenerator/blocked_words.txt`](UsernameGenerator/blocked_words.txt) lists the ones the generator skips. To block another word, add it on its own line and rebuild. The tests catch typos.

## Credits

Words come from the [EFF Large Wordlist](https://www.eff.org/dice) by the Electronic Frontier Foundation, used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## License

MIT. See [LICENSE](LICENSE).
