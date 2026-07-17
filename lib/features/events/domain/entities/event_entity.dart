import 'package:equatable/equatable.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';

/// Event entity representing an event in the system.
class Event extends Equatable {
  final int id;
  final String name;
  final String slug;
  final ImageUrls? poster;
  final DateTime eventDateTime;
  final int durationHours;
  final String locationName;
  final String? locationLink;
  final bool hasFee;
  final int registrationFee;
  final bool hasPrize;
  final int prizeAmount;
  final bool isOnline;
  final DateTime? registrationStartDate;
  final DateTime? registrationEndDate;
  final ClubSummary club;
  final Category category;
  final List<Interest> interests;
  final List<EventField> additionalFields;
  final double rating;
  final int totalRatings;
  final String? description;
  final String? contactPhone;
  final String? contactEmail;
  final String? externalUrl;

  const Event({
    required this.id,
    required this.name,
    required this.slug,
    this.poster,
    required this.eventDateTime,
    required this.durationHours,
    required this.locationName,
    this.locationLink,
    this.hasFee = false,
    this.registrationFee = 0,
    this.hasPrize = false,
    this.prizeAmount = 0,
    this.isOnline = false,
    this.registrationStartDate,
    this.registrationEndDate,
    required this.club,
    required this.category,
    this.interests = const [],
    this.additionalFields = const [],
    this.rating = 0,
    this.totalRatings = 0,
    this.description,
    this.contactPhone,
    this.contactEmail,
    this.externalUrl,
  });

  /// Check if registration is currently open.
  bool get isRegistrationOpen {
    final now = DateTime.now();
    if (registrationStartDate != null && now.isBefore(registrationStartDate!)) {
      return false;
    }
    if (registrationEndDate != null && now.isAfter(registrationEndDate!)) {
      return false;
    }
    return true;
  }

  /// Time remaining until registration closes.
  Duration? get timeUntilRegistrationCloses {
    if (registrationEndDate == null) return null;
    final diff = registrationEndDate!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Check if the event is free.
  bool get isFree => !hasFee || registrationFee == 0;

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        poster,
        eventDateTime,
        durationHours,
        locationName,
        locationLink,
        hasFee,
        registrationFee,
        hasPrize,
        prizeAmount,
        isOnline,
        registrationStartDate,
        registrationEndDate,
        club,
        category,
        interests,
        additionalFields,
        rating,
        totalRatings,
        description,
        contactPhone,
        contactEmail,
        externalUrl,
      ];
}

/// Summary of a club for displaying in event cards.
class ClubSummary extends Equatable {
  final int id;
  final String name;
  final String slug;
  final ImageUrls? logo;

  const ClubSummary({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
  });

  @override
  List<Object?> get props => [id, name, slug, logo];
}

/// Event category entity.
class Category extends Equatable {
  final int id;
  final String name;
  final String? icon;
  final String? iconType;

  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.iconType,
  });

  @override
  List<Object?> get props => [id, name, icon, iconType];
}

/// Additional field for event registration forms.
class EventField extends Equatable {
  final String key;
  final String label;
  final FieldType fieldType;
  final bool isRequired;
  final List<String> options;

  const EventField({
    required this.key,
    required this.label,
    required this.fieldType,
    this.isRequired = false,
    this.options = const [],
  });

  @override
  List<Object?> get props => [key, label, fieldType, isRequired, options];
}

/// Types of form fields.
enum FieldType {
  text,
  number,
  email,
  phone,
  dropdown,
  radio,
  checkbox,
  date,
  textarea,
}

/// Event list item for displaying in lists.
class EventListItem extends Equatable {
  final int id;
  final String name;
  final String slug;
  final ImageUrls? poster;
  final DateTime eventDateTime;
  final String locationName;
  final bool isOnline;
  final bool hasFee;
  final int registrationFee;
  final ClubSummary club;
  final Category category;

  const EventListItem({
    required this.id,
    required this.name,
    required this.slug,
    this.poster,
    required this.eventDateTime,
    required this.locationName,
    this.isOnline = false,
    this.hasFee = false,
    this.registrationFee = 0,
    required this.club,
    required this.category,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        poster,
        eventDateTime,
        locationName,
        isOnline,
        hasFee,
        registrationFee,
        club,
        category,
      ];
}
