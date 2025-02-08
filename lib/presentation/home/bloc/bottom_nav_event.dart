
sealed class BottomNavigatorEvent {
  const BottomNavigatorEvent();
}


class UpdateIndexEvent extends BottomNavigatorEvent {
    const UpdateIndexEvent({required this.index});  
  final int index; 
}
