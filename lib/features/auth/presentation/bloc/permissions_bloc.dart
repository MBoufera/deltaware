import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'permissions_event.dart';
import 'permissions_state.dart';

class PermissionsBloc extends Bloc<PermissionsEvent, PermissionsState> {
  PermissionsBloc() : super(PermissionsState()) {
    on<LoadPermissions>(_onLoadPermissions);
    on<ClearPermissions>(_onClearPermissions);
  }

  Future<void> _onLoadPermissions(LoadPermissions event, Emitter<PermissionsState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    if (event.role == 'admin') {
      emit(state.copyWith(isLoading: false, isAdmin: true, permissions: {}));
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_permissions')
          .select()
          .eq('user_id', event.userId)
          .maybeSingle();

      if (response != null) {
        emit(state.copyWith(
          isLoading: false,
          isAdmin: false,
          permissions: response,
        ));
      } else {
        emit(state.copyWith(isLoading: false, isAdmin: false, permissions: {}));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, isAdmin: false, permissions: {}));
    }
  }

  void _onClearPermissions(ClearPermissions event, Emitter<PermissionsState> emit) {
    emit(PermissionsState()); // reset to default loading state
  }
}
