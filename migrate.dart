import 'dart:developer';

import 'package:postgres/postgres.dart';
import 'dart:io';

void main() async {
  log('Connecting to Supabase PostgreSQL...');
  final connection = await Connection.open(
    Endpoint(
      host: 'aws-0-eu-west-1.pooler.supabase.com',
      database: 'postgres',
      username: 'postgres.dggulctustnlfyadcanx',
      password: 'DeltawareStationary2026',
      port: 5432,
    ),
    settings: ConnectionSettings(sslMode: SslMode.require),
  );

  log('Reading schema_v2.sql...');
  final sql = await File('schema_v2.sql').readAsString();

  log('Executing migration...');
  await connection.execute(sql);

  log('Migration completed successfully!');
  await connection.close();
}
