/// The live room's addresses in the app, by the event's id or slug ([ref]).
/// Kept apart from the routes' builders so the push and link code can name
/// them without the screens.
library;

/// The room: `/events/{ref}/live` (the website's address too).
String liveRoomLocation(Object ref) =>
    '/events/${Uri.encodeComponent('$ref')}/live';

/// The quiz: `/events/{ref}/live/quiz`.
String liveQuizLocation(Object ref) => '${liveRoomLocation(ref)}/quiz';
