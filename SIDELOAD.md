# Build Noop from Windows and install with Sideloadly

## 1. Put the code on GitHub (once)
1. Make a free account at github.com and click **New repository**. Name it `noop`. Set it to **Public** (public repos get free Mac build time). Create it.
2. Unzip Noop.zip. Open the new repo, click **uploading an existing file**, and drag in EVERYTHING inside the unzipped `Noop` folder (the `Noop` subfolder, `project.yml`, `README.md`, `SIDELOAD.md`, and the hidden `.github` folder).
   - Windows hides nothing here, but dragging the hidden `.github` folder can be fiddly. If the build never starts, open the repo, press **Add file > Create new file**, type `.github/workflows/build.yml` as the name, and paste in the contents of that file.
3. Click **Commit changes**.

## 2. Let GitHub build it
1. Open the **Actions** tab. A run called "Build Noop IPA" starts by itself. It takes about 5-10 minutes.
2. A green check means it worked. Click the run, scroll to **Artifacts**, and download **Noop-ipa** (a zip containing `Noop.ipa`). Unzip it.
3. A red X means a compile error. Click the failed step, copy the red error lines, and paste them to me. I'll fix the code and you upload the changed file.

## 3. Install with Sideloadly
1. Plug in your iPhone, tap Trust on the phone. In Sideloadly, pick the phone.
2. Drag `Noop.ipa` in, type your Apple ID, and press **Start**.
3. On the iPhone: Settings > General > VPN & Device Management > your Apple ID > Trust.
4. Turn on Developer Mode if asked: Settings > Privacy & Security > Developer Mode.
5. Open Noop. It starts on demo data. Profile > Connect Apple Health to use real data.

It expires after 7 days with a free Apple ID. Re-run Sideloadly with the same file to refresh it.

## If Apple Health won't connect
Sideloading with a free Apple ID sometimes strips the HealthKit permission. If Profile > Connect Apple Health does nothing or Health data stays empty, that's why. The app still works on demo data.
