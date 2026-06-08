import 'package:postgres/postgres.dart';
import 'dart:io';

void main() async {
  print('Connecting to Supabase PostgreSQL...');
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

  print('Reading schema_v2.sql...');
  final sql = await File('schema_v2.sql').readAsString();

  print('Executing migration...');
  await connection.execute(sql);

  print('Migration completed successfully!');
  await connection.close();
}
