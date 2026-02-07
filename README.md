# vanguardfyp

A fyp project.

## PayPal Sandbox account (optional)

To use **Pay with PayPal (Sandbox account)** in the app (log in on PayPal and approve payment):

1. In [PayPal Developer](https://developer.paypal.com/) create a sandbox app and note the **Client ID** and **Secret** (sandbox).
2. In **Google Cloud Console** → your project → **Cloud Run** → select a function (e.g. `createPayPalOrder`) → **Edit** → **Variables and secrets** (or set at project level), add:
   - `PAYPAL_CLIENT_ID` = your sandbox Client ID  
   - `PAYPAL_CLIENT_SECRET` = your sandbox Secret  
3. Redeploy Cloud Functions so they pick up the new env vars.

Without these, the “Pay with PayPal (Sandbox account)” option will show a configuration error; card payment (simulated) still works.

## Testing from other PCs / devices

All app features (Firebase Auth, Firestore, Cloud Functions, PayPal sandbox payment) work from **any PC or device** with internet; only the **blockchain (Ganache)** payment needs one extra step if you run the app on a different machine than where Ganache runs.

- **Firebase**: Uses cloud by default — no local-only config. Works from any network.
- **Blockchain (Ganache)**: By default the app uses `localhost` or (on Android emulator) the host’s IP. To test from **other PCs or phones** using one shared Ganache:
  1. Run Ganache on one computer and set its RPC Server to **HTTP://0.0.0.0:7545**.
  2. In Firebase Console → Firestore, add a document: **Collection** `settings`, **Document ID** `blockchain`, with field **`rpcUrl`** (string) = `http://<that computer's LAN IP>:7545` (e.g. `http://192.168.1.100:7545`).
  3. Ensure the Ganache host allows port 7545 in its firewall. All devices that open the app will then use this RPC URL and can run blockchain payment tests against the same Ganache.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
