enum RecordingInterruptionReason {
  unknown,
  invalidBuffer,
  queueError,
  fileError,
  sessionError,
  systemInterruption,
  stopPanic,
  startPanic,
}

class RecordingInterruptionEvent {
  final RecordingInterruptionReason reason;
  final String message;

  RecordingInterruptionEvent(this.reason, this.message);

  factory RecordingInterruptionEvent.fromMap(Map map) {
    RecordingInterruptionReason reason;

    switch (map['reason']) {
      case 'invalid_buffer':
        reason = RecordingInterruptionReason.invalidBuffer;
        break;
      case 'queue_error':
        reason = RecordingInterruptionReason.queueError;
        break;
      case 'file_error':
        reason = RecordingInterruptionReason.fileError;
        break;
      case 'session_error':
        reason = RecordingInterruptionReason.sessionError;
        break;
      case 'system_interruption':
        reason = RecordingInterruptionReason.systemInterruption;
        break;
      case 'start_panic':
        reason = RecordingInterruptionReason.startPanic;
        break;
      case 'stop_panic':
        reason = RecordingInterruptionReason.stopPanic;
        break;
      default:
        reason = RecordingInterruptionReason.unknown;
    }

    return RecordingInterruptionEvent(reason, map['message'] ?? '');
  }
}
