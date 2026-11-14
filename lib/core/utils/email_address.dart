/// Whether [text] looks enough like an email address to send: one `@`,
/// something before it, and a domain with a dot and at least two
/// characters after its last dot. No spaces. The website's check
/// (moa_eventwebsite `validateAnswer`).
///
/// Deliberately loose: `name+tag@gmail.com`, `asha@college.academy` and
/// `x@mail.co.in` are all real addresses. The server is the judge of the
/// rest, and a stricter check here only shut people out of registering.
bool looksLikeEmail(String text) => _email.hasMatch(text.trim());

final _email = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)*\.[^\s@.]{2,}$');
