import 'dart:convert';

/// A made-up profile that repeats the SHAPE of a real 42 API response
/// (see docs/03) but without a single real value.
///
/// The data is run through `jsonEncode` -> `jsonDecode`, as in the app: so the
/// types are the same as after a real HTTP response.
Map<String, dynamic> sampleUserJson() {
  final raw = <String, dynamic>{
    'id': 1,
    'login': 'jdoe',
    'displayname': 'Jane Doe',
    'email': 'jdoe@example.com',
    'phone': 'hidden',
    'location': null,
    'wallet': 42,
    'correction_point': 5,
    'pool_month': 'september',
    'pool_year': '2023',
    'anonymize_date': '2030-01-01T00:00:00.000Z',
    'image': {
      'link': 'https://example.com/link.jpg',
      'versions': {
        'large': 'https://example.com/large.jpg',
        'medium': 'https://example.com/medium.jpg',
        'small': 'https://example.com/small.jpg',
        'micro': 'https://example.com/micro.jpg',
      },
    },
    // The order is deliberately "inconvenient": the main cursus is neither
    // first nor the one with the highest level.
    'cursus_users': [
      {
        'cursus_id': 9,
        'level': 5.02,
        'begin_at': '2023-09-01T00:00:00.000Z',
        'end_at': '2023-09-30T00:00:00.000Z',
        'cursus': {'id': 9, 'name': 'C Piscine', 'slug': 'c-piscine'},
        'skills': [
          {'id': 1, 'name': 'Unix', 'level': 3.4699999999999998},
        ],
      },
      {
        'cursus_id': 21,
        'level': 3.0,
        'begin_at': '2023-11-01T00:00:00.000Z',
        'end_at': null,
        'cursus': {'id': 21, 'name': '42cursus', 'slug': '42cursus'},
        'skills': [
          {'id': 2, 'name': 'Rigor', 'level': 9.63},
          {'id': 3, 'name': 'Web', 'level': 7},
          {'id': 4, 'level': 'abc'},
        ],
      },
      {
        'cursus_id': 7,
        'level': 0.0,
        'cursus': {'id': 7, 'name': 'C-Piscine-Reloaded', 'slug': 'c-piscine-reloaded'},
        'skills': [],
      },
    ],
    'projects_users': [
      {
        'id': 1,
        'status': 'finished',
        'validated?': true,
        'final_mark': 100,
        'marked_at': '2024-03-01T10:00:00.000Z',
        'cursus_ids': [21],
        'project': {'id': 10, 'name': 'libft', 'slug': 'libft', 'parent_id': null},
      },
      {
        'id': 2,
        'status': 'finished',
        'validated?': false,
        'final_mark': 0,
        'marked_at': '2024-05-01T10:00:00.000Z',
        'cursus_ids': [21],
        'project': {'id': 11, 'name': 'ft_printf', 'slug': 'ft_printf'},
      },
      {
        // No name, no result, no marked_at: we take the slug and updated_at.
        'id': 3,
        'status': 'finished',
        'validated?': null,
        'final_mark': null,
        'marked_at': null,
        'updated_at': '2024-04-01T10:00:00.000Z',
        'cursus_ids': [9],
        'project': {'id': 12, 'slug': 'c-piscine-shell-00'},
      },
      {
        // A strange case from real data: not finished, but validated? == true.
        'id': 4,
        'status': 'in_progress',
        'validated?': true,
        'final_mark': null,
        'cursus_ids': [21],
        'project': {'id': 13, 'name': 'minishell', 'slug': 'minishell'},
      },
      'junk instead of an object',
      {
        'id': 6,
        'status': 'finished',
        'validated?': true,
        'final_mark': 125,
        'marked_at': '2024-06-01T10:00:00.000Z',
        'cursus_ids': [21],
        'project': {'id': 14, 'name': 'push_swap', 'slug': 'push_swap'},
      },
    ],
  };
  return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
}
