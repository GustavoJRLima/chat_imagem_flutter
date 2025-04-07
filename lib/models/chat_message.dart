class ChatMessage {
  final String id;
  final String msg;
  final String nick;
  final String type;
  final int timestamp;

  ChatMessage({
    required this.id,
    required this.msg,
    required this.nick,
    required this.type,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      msg: map['msg'],
      nick: map['nick'],
      type: map['type'],
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'msg': msg,
      'nick': nick,
      'type': type,
      'timestamp': timestamp,
    };
  }
}
