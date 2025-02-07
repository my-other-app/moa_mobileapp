import 'package:flutter_bloc/flutter_bloc.dart' show Bloc, Emitter;
import 'package:myotherapp/presentation/home/bloc/bottom_nav_event.dart';
import 'package:myotherapp/presentation/home/bloc/bottom_nav_state.dart';


class BottomNavigatorBloc extends Bloc<BottomNavigatorEvent , BottomNavigatorState>{
 BottomNavigatorBloc({required int index }) : super (const InitialBottomNavigatorState(index: 0)) {
  on<UpdateIndexEvent>(_onUpdateIndexEvent);
 }

 Future<void> _onUpdateIndexEvent(UpdateIndexEvent event , Emitter<BottomNavigatorState> emit)async{
   emit(UpdatedBottomNavigatorState(index: event.index));
 }
}