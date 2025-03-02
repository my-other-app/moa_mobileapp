
sealed class BottomNavigatorState  {
  final int index;
  const BottomNavigatorState({required this.index});


}

class UpdatedBottomNavigatorState extends BottomNavigatorState {
  const UpdatedBottomNavigatorState({required super.index});
} 

class InitialBottomNavigatorState extends BottomNavigatorState {
const InitialBottomNavigatorState({required super.index}); 
}

