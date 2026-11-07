// The shared test form every repo tests (conditional-questions-contract.md
// §12), exactly as a read endpoint sends it (§5): a question with `show_if`
// goes out as `required: false` with the club's setting in
// `required_when_shown`; one without goes out as it always has.
//
//   1 status       radio   [Student, Working]  required
//   2 college      text                        required  show_if status ∈ [Student]
//   3 year         select  [1, 2, 3, 4]        required  show_if status ∈ [Student]
//   4 degree_type  radio   [UG, PG]            required  show_if status ∈ [Student]
//   5 pg_spec      text                        required  show_if degree_type ∈ [PG]
//   6 company      text                        required  show_if status ∈ [Working]
//   7 experience   select  [0-2, 3-5, 5+]      required  show_if status ∈ [Working]
//   8 tshirt       select  [S, M, L, XL]       required

import 'package:finnet/common/models/events/event_model.dart';

Map<String, dynamic> _conditional(String key, String label, String type,
        {required String parent,
        required List<String> anyOf,
        List<String>? options}) =>
    {
      'key': key,
      'label': label,
      'field_type': type,
      'required': false,
      'required_when_shown': true,
      'options': options,
      'show_if': {'key': parent, 'any_of': anyOf},
    };

/// `additional_details` of the shared form, as `/events/info` sends it.
final List<Map<String, dynamic>> sharedFormJson = [
  {
    'key': 'status',
    'label': 'Are you working or a student?',
    'field_type': 'radio',
    'required': true,
    'options': ['Student', 'Working'],
  },
  _conditional('college', 'College name', 'text',
      parent: 'status', anyOf: ['Student']),
  // The options as numbers, as JSON may carry them.
  {
    ..._conditional('year', 'Year of study', 'select',
        parent: 'status', anyOf: ['Student']),
    'options': [1, 2, 3, 4],
  },
  _conditional('degree_type', 'Degree type', 'radio',
      parent: 'status', anyOf: ['Student'], options: ['UG', 'PG']),
  _conditional('pg_spec', 'PG specialisation', 'text',
      parent: 'degree_type', anyOf: ['PG']),
  _conditional('company', 'Company', 'text',
      parent: 'status', anyOf: ['Working']),
  _conditional('experience', 'Years of experience', 'select',
      parent: 'status', anyOf: ['Working'], options: ['0-2', '3-5', '5+']),
  {
    'key': 'tshirt',
    'label': 'T-shirt size',
    'field_type': 'select',
    'required': true,
    'options': ['S', 'M', 'L', 'XL'],
  },
];

List<AdditionalDetail> sharedForm() =>
    sharedFormJson.map(AdditionalDetail.fromJson).toList();

/// Every question answered, whatever the path -- what an app older than
/// conditions could send, since it shows them all.
const everyAnswer = <String, Object?>{
  'status': 'Student',
  'college': 'CET',
  'year': '2',
  'degree_type': 'PG',
  'pg_spec': 'Data science',
  'company': 'Acme',
  'experience': '3-5',
  'tshirt': 'M',
};
