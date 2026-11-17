import SwiftUI

/// "Networking", large: on top, the code, the name, "Scan to save me", the
/// Scan pill and "Network · 12" (the medium widget); below, "Recently met"
/// -- the four people met last, newest first, each with their initials in a
/// circle of their own colour (or their photo, when the person turned
/// photos on and it was kept), their name and the event they met at, each
/// opening their page in the app -- and "3 without a note yet ›", which
/// opens the Network tab.
///
/// Laid out by the space there is (an iPhone SE's large widget is 30 points
/// shorter than a Pro Max's): the code takes a little over a third of the
/// height, the people share the rest, on one line each when two won't fit.
/// The names are hidden while the phone is locked (StandBy), as the code.
struct NetworkingLarge: View {
  let data: NetworkingData
  let palette: WidgetPalette
  let scheme: ColorScheme
  let photos: [String: CGImage]

  /// The rows' heights between which two lines (the name, then the event)
  /// fit, and the most a row takes.
  static let twoLineRow: CGFloat = 33
  static let tallestRow: CGFloat = 40

  var body: some View {
    GeometryReader { space in
      let top = min(132, (space.size.height * 0.37).rounded())
      let people = data.recentlyMet()
      let footer: CGFloat = data.noNoteLine == nil ? 0 : 20
      let rowsHeight = space.size.height - top - 12 - 18 - footer
      let row = min(NetworkingLarge.tallestRow, rowsHeight / 4)
      VStack(alignment: .leading, spacing: 0) {
        NetworkingMedium(data: data, palette: palette)
          .frame(height: top)
        Text("Recently met")
          .font(WidgetFonts.text(10, .semibold))
          .textCase(.uppercase)
          .foregroundColor(palette.accent)
          .padding(.top, 12)
          .padding(.bottom, 4)
          .frame(height: 30, alignment: .bottomLeading)
        if people.isEmpty {
          Text(
            data.met == nil
              ? "The people you meet show here."
              : "Scan someone’s code to save them. They show here."
          )
          .font(WidgetFonts.text(12))
          .foregroundColor(palette.secondary)
          .lineLimit(2)
        } else {
          ForEach(Array(people.enumerated()), id: \.offset) { _, person in
            WidgetLink(destination: person.url) {
              MetRow(
                person: person, photo: person.photo.flatMap { photos[$0] }, height: row,
                palette: palette, scheme: scheme)
            }
          }
        }
        Spacer(minLength: 0)
        if let line = data.noNoteLine {
          WidgetLink(destination: data.networkURL) {
            Text(line)
              .font(WidgetFonts.text(12, .semibold))
              .lineLimit(1)
              .foregroundColor(palette.accent)
          }
          .frame(height: footer, alignment: .bottomLeading)
        }
      }
      .frame(width: space.size.width, height: space.size.height, alignment: .topLeading)
    }
  }
}

/// One person on "Recently met": their circle, their name and the event.
struct MetRow: View {
  let person: NetworkingData.Met
  let photo: CGImage?
  let height: CGFloat
  let palette: WidgetPalette
  let scheme: ColorScheme

  var body: some View {
    let twoLines = height >= NetworkingLarge.twoLineRow
    HStack(spacing: 10) {
      PersonCircle(
        person: person, photo: photo, side: min(30, height - 6), scheme: scheme,
        outline: palette.tileOutline)
      if twoLines {
        VStack(alignment: .leading, spacing: 0) {
          Text(person.name)
            .font(WidgetFonts.text(13, .semibold))
            .foregroundColor(palette.ink)
          if let event = person.event {
            Text(event)
              .font(WidgetFonts.text(11))
              .foregroundColor(palette.secondary)
          }
        }
        .lineLimit(1)
      } else {
        (Text(person.name).foregroundColor(palette.ink)
          + Text(person.event.map { " · \($0)" } ?? "").foregroundColor(palette.secondary))
          .font(WidgetFonts.text(12, .semibold))
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .frame(height: height)
    .privateWhenLocked()
  }
}

/// Someone's photo in a circle, or their initials on their colour.
struct PersonCircle: View {
  let person: NetworkingData.Met
  let photo: CGImage?
  let side: CGFloat
  let scheme: ColorScheme
  let outline: Color

  var body: some View {
    let colours = WidgetPalette.circle(person.colour ?? 0, scheme)
    ZStack {
      if let photo = photo {
        Image(decorative: photo, scale: 1)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        Circle().fill(colours.fill)
        Text(person.shownInitials)
          .font(WidgetFonts.text(side * 0.4, .semibold))
          .foregroundColor(colours.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
    }
    .frame(width: max(side, 0), height: max(side, 0))
    .clipShape(Circle())
    .overlay(Circle().stroke(outline, lineWidth: 1))
    .accessibilityHidden(true)
  }
}
