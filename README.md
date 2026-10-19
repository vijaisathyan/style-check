# Style Check

A free, offline Mac app for asking grammar and style questions while editing academic and literary journals. It runs an open-source language model on your Mac and answers from the style guides you give it, citing the passage it used.

- **Offline.** After a one-time model download, nothing leaves your Mac and no internet is needed.
- **Your guides.** Drag in PDFs, Word files, RTF, HTML, Markdown, or text. Scanned PDFs are read with macOS's built-in OCR.
- **Cited answers.** Every answer shows the passages it was based on, so you can check the rule yourself.
- **Light on memory.** Built for an M1 MacBook Air with 8 GB: one 4-bit model (about 2–3 GB), freed automatically when idle.

## What you can ask

- "Should there be a comma before *and* in a list of three?"
- "Check this: *The data shows that 5 participants, who were students, left early.*"
- "How do I write the page range 101 to 108?"
- "How do I capitalize *a history of the world in ten chapters* as a title?"
- "What does the house style guide say about *toward* versus *towards*?"

## About the Chicago Manual of Style

*The Chicago Manual of Style* is copyrighted by the University of Chicago Press, so it isn't included here. The app ships with a **Chicago Quick Reference**, about 40 common Chicago-style conventions written in our own words. It carries no section numbers. For authoritative rulings:

- If you have a licensed CMOS copy (PDF or saved pages), add it to the library. It stays on your Mac only.
- Free, public-domain guides you can add today:
  - [GPO Style Manual (2016)](https://www.govinfo.gov/app/details/GPO-STYLEMANUAL-2016), the US government's manual covering grammar, punctuation, capitalization, and numbers. Some of its conventions differ from Chicago's; answers say which guide they come from.
  - Your journal's own house style sheet or author guidelines.

## Install

1. Download the latest **StyleCheck-x.y.z.dmg** from [Releases](https://github.com/vijaisathyan/style-check/releases).
2. Open it and drag **Style Check** onto **Applications**.
3. Open Style Check from Applications. The first time, macOS may say it can't verify the app, because it isn't signed with a paid Apple Developer ID. Go to **System Settings ▸ Privacy & Security**, scroll down, and click **Open Anyway**. You only do this once.

**Requirements:** a Mac with Apple silicon (M1 or later), macOS 15 or later, 8 GB of memory, and about 3 GB of free disk space. Intel Macs aren't supported, because the MLX model engine runs only on Apple-silicon GPUs.

## Build from source

You need Xcode 26 or later.

**In Xcode:** open the `style-check` folder (File ▸ Open…), wait for packages to resolve, choose the **StyleCheck** scheme and **My Mac**, then press **⌘R**. On the first build, accept Xcode's offer to download the **Metal Toolchain**; MLX needs it to compile its GPU kernels. The first build compiles MLX from source and takes several minutes on an M1 Air.

**As an app and disk image:**

```bash
git clone https://github.com/vijaisathyan/style-check.git
cd style-check
./scripts/make-dmg.sh          # builds dist/Style Check.app and dist/StyleCheck-<version>.dmg
```

`./scripts/make-app.sh` builds just the app. Use Xcode or `xcodebuild`, not `swift build`: only Xcode's build system compiles MLX's Metal shaders.

### Releases

GitHub Actions builds the app on an Apple-silicon Mac for every push to `main` (the disk image is attached to the workflow run) and publishes a Release for every version tag:

```bash
git tag v0.2.0 && git push origin v0.2.0
```

Each build runs `StyleCheck --self-test` on the packaged app, which checks that the bundled Metal shaders load and the GPU works.

**Removing the "Open Anyway" step (optional):** with an Apple Developer Program membership, add the repository secrets listed at the top of `.github/workflows/release.yml`. Builds are then signed with your Developer ID and notarized by Apple, so the app opens on any Mac without warnings.

## First launch

1. Pick a model and click **Download**. This is the only step that needs internet.
   | Model | Download | Notes |
   |---|---|---|
   | Qwen3 4B (recommended) | 2.3 GB | Best answers that fit comfortably in 8 GB |
   | Llama 3.2 3B | 1.8 GB | Lighter, quick |
   | Qwen3 1.7B | 1.0 GB | Fastest; less reliable explanations |
2. Add style guides with **Add Style Guide…** (⌘O) or by dropping files on the sidebar.
3. Ask a question.

Fully offline install: download an MLX model folder on another machine (for example `mlx-community/Qwen3-4B-4bit` from Hugging Face), copy it over, and choose **I already have an MLX model folder…** on the setup screen.

## How it works

```
question ──► keyword search (BM25) over your guides ──► top 4 passages
                                                          │
                     answer with [citations] ◄── local LLM (MLX, 4-bit)
```

- **Search:** guides are split into passages of about 200 words and indexed with BM25, plus a small synonym table (for example, "Oxford comma" also matches "serial comma"). It needs no extra model and almost no memory.
- **Model:** [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) runs a 4-bit model on the GPU. Each question starts a fresh session with the last two exchanges attached, so memory doesn't grow over a long chat.
- **Memory:** MLX's buffer cache is capped at 64 MB, and the model is unloaded after 10 idle minutes (adjustable in Settings).
- **Storage:** extracted guide text is kept in `~/Library/Application Support/StyleCheck/Library`. Original files are not copied.

### Code layout

| Path | What it is |
|---|---|
| `Sources/StyleCheckCore` | UI-free logic: chunking, search, library storage, prompts, built-in reference |
| `Sources/StyleCheck/Model` | Model catalog, download, loading, generation |
| `Sources/StyleCheck/Library` | Document import (PDFKit, Vision OCR, AppKit text readers) |
| `Sources/StyleCheck/Chat` | Conversation state and the question → answer loop |
| `Sources/StyleCheck/Views` | SwiftUI screens |
| `Tests/StyleCheckCoreTests` | Search and chunking tests (`swift test`) |

## Limitations

- A 3–4B model is a capable assistant, not an authority. It can misstate a rule, so check the cited passages. When the guides don't cover a question, the answer says so.
- Very long questions or pasted passages (more than about a page) get slower. Check a paragraph at a time.
- Search matches words, not meaning. If an answer misses, rephrase with the term the guide likely uses ("en dash" rather than "the medium dash").

## License

MIT for this code. Models keep their own licenses (Apache 2.0 for Qwen3, the Llama 3.2 Community License for Llama).
