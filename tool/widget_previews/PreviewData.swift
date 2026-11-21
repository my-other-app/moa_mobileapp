import Foundation

/// The Networking widget's faces, for the previews.
enum PreviewData {
  static let networking: [(String, NetworkingData)] = [
    ("ready", NetworkingData.parse(#"{"v":1,"state":"ready","name":"Asha Menon","profile_link":"https://myotherapp.in/p/abcdefghjk","network":12}"#)),
    ("no-qr", NetworkingData.parse(#"{"v":1,"state":"no_qr","name":"Asha Menon"}"#)),
    ("signed-out", NetworkingData.signedOut),
  ]
}
