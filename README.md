# UsernameGenerator

A small, private username generator for iPhone, iPad, Mac and Apple Vision Pro.

Pick how many words, a separator, the capitalization, and whether to add digits. You get five options at once, like `QuietOtter4821` or `brave-falcon-07`. Tap one to copy it.

- **Themes:** animals, nature, space, food, ocean, weather, music, colors, fantasy, sports, spooky, tech, mythology or gems vocabularies.
- **Made-up words:** switch *Vocabulary* to *Made-up* for pronounceable words that aren't in any dictionary, like `Vorak` or `Telum`. They are built on your device from syllables, and checked against the word filter.
- **Spelling:** *Leetspeak* turns `Otter` into `0tt3r`, and *No vowels* turns it into `Ottr`. You can pick several.
- **Your own word:** type a word and it goes at the start or end of every username, like `cole-BraveBadger`.
- **Keep a word:** press and hold a username (right-click on Mac) and choose *Keep “otter”* to hold that word while the rest are rerolled.
- **Patterns:** *Adjective + noun* gives names like `BraveBadger`, and *Alliterate* makes every word start with the same letter.
- **Strength meter:** shows how many usernames your current settings can produce.
- **Control Center:** add the *New Username* control to copy a fresh username in one tap.
- **Site rules:** cap the length (6–30) or allow letters and numbers only. If a limit is tight, digits and then words are dropped so every result fits.
- **Shortcuts, Siri and Spotlight:** a *Generate Username* action with all the same options.
- **Keyboard (iPhone and iPad):** add *Username Keyboard* in Settings → General → Keyboard → Keyboards, then tap a username to type it into any app. It has its own quick options (1–3 words, digits, a length limit). It never asks for *Allow Full Access*, so it can't use the network. It has no letter keys and never reads the text around the cursor.
- **Safari extension:** click the toolbar button for five usernames. Click one to copy it and fill the text field you're in. On Mac you can also right-click a field and choose *Generate Username*. Turn it on in Safari's Extensions settings.

## Privacy

- Everything runs on your device. No accounts, analytics, ads or network access.
- Generated usernames are never saved. Only your option choices are remembered, including the word you type under *Your word*. A word you keep from a result is forgotten when you close the app.
- The keyboard does not request Full Access. Apple then keeps it offline and sandboxed, and it can't read your options from the app, so it remembers its own few settings.
- The Safari extension has no access to websites until you click it (`activeTab`). It only writes into the focused text field, and never reads page content.
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
