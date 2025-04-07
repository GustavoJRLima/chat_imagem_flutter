import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:web_socket_client/web_socket_client.dart';
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key, required this.name, required this.id})
    : super(key: key);

  final String name;
  final String id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final socket = WebSocket(Uri.parse('ws://localhost:8765'));
  final List<types.Message> _messages = [];
  late types.User me;
  late types.User otherUser;
  final database = FirebaseDatabase.instance.ref('chatMessages');

  @override
  void initState() {
    super.initState();
    me = types.User(id: widget.id, firstName: widget.name);
    otherUser = const types.User(id: 'other');

    _listenToWebSocket();
    _loadMessagesFromFirebase();
  }

  void _listenToWebSocket() {
    socket.messages.listen((incomingMessage) {
      if (incomingMessage is String) {
        try {
          Map<String, dynamic> data = jsonDecode(
            incomingMessage.split(' from ')[0],
          );

          if (data['id'] != me.id) {
            types.User sender = types.User(
              id: data['id'],
              firstName: data['nick'] ?? data['id'],
            );

            types.Message newMessage;
            switch (data['type']) {
              case 'image':
                newMessage = types.ImageMessage(
                  author: sender,
                  id: data['timestamp'],
                  uri: data['msg'],
                  createdAt: int.parse(data['timestamp']),
                  name: 'Image',
                  size: 0,
                  width: 0,
                  height: 0,
                );
                break;
              case 'file':
                newMessage = types.FileMessage(
                  author: sender,
                  id: data['timestamp'],
                  uri: data['msg'],
                  name: 'File',
                  size: 0,
                  createdAt: int.parse(data['timestamp']),
                );
                break;
              default:
                newMessage = types.TextMessage(
                  author: sender,
                  id: data['timestamp'],
                  text: data['msg'],
                  createdAt: int.parse(data['timestamp']),
                );
            }

            _addMessage(newMessage);
          }
        } catch (e) {
          debugPrint("Erro ao processar mensagem do WebSocket: $e");
        }
      }
    });
  }

  Future<void> _loadMessagesFromFirebase() async {
    final snapshot = await database.get();
    if (snapshot.exists) {
      final List<types.Message> loadedMessages = [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        final msgData = Map<String, dynamic>.from(value);

        types.User sender = types.User(
          id: msgData['id'],
          firstName: msgData['nick'],
        );

        types.Message msg;
        switch (msgData['type']) {
          case 'image':
            msg = types.ImageMessage(
              author: sender,
              id: msgData['timestamp'],
              uri: msgData['msg'],
              createdAt: int.parse(msgData['timestamp']),
              name: 'Image',
              size: 0,
              width: 0,
              height: 0,
            );
            break;
          case 'file':
            msg = types.FileMessage(
              author: sender,
              id: msgData['timestamp'],
              uri: msgData['msg'],
              name: 'File',
              size: 0,
              createdAt: int.parse(msgData['timestamp']),
            );
            break;
          default:
            msg = types.TextMessage(
              author: sender,
              id: msgData['timestamp'],
              text: msgData['msg'],
              createdAt: int.parse(msgData['timestamp']),
            );
        }

        loadedMessages.add(msg);
      });

      loadedMessages.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

      setState(() {
        _messages.addAll(loadedMessages);
      });
    }
  }

  void _saveMessageToFirebase(Map<String, dynamic> messageData) async {
    final newMsgRef = database.push();
    await newMsgRef.set(messageData);
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _sendMessageCommon(types.Message message) {
    String content;
    String type;

    if (message is types.TextMessage) {
      content = message.text;
      type = 'text';
    } else if (message is types.ImageMessage) {
      content = message.uri;
      type = 'image';
    } else if (message is types.FileMessage) {
      content = message.uri;
      type = 'file';
    } else {
      debugPrint("Unsupported message type");
      return;
    }

    var data = {
      'id': me.id,
      'msg': content,
      'nick': me.firstName,
      'timestamp': message.createdAt.toString(),
      'type': type,
    };

    socket.send(jsonEncode(data));
    _saveMessageToFirebase(data);
    _addMessage(message);
  }

  void _handleSendPressed(types.PartialText message) {
    final msg = types.TextMessage(
      author: me,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _randomString(),
      text: message.text,
    );
    _sendMessageCommon(msg);
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleImageSelection();
                  },
                  child: const Text('Foto'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleFileSelection();
                  },
                  child: const Text('Arquivo'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
    );
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1440,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final message = types.ImageMessage(
        author: me,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: image.height.toDouble(),
        width: image.width.toDouble(),
        id: _randomString(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
      );

      _sendMessageCommon(message);
    }
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;

      final message = types.FileMessage(
        author: me,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _randomString(),
        mimeType: lookupMimeType(file.path!) ?? 'application/octet-stream',
        name: file.name,
        size: file.size,
        uri: file.path!,
      );

      _sendMessageCommon(message);
    }
  }

  String _randomString() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seu Chat: ${widget.name}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Chat(
        onAttachmentPressed: _handleAttachmentPressed,
        messages: _messages,
        user: me,
        showUserAvatars: true,
        showUserNames: true,
        onSendPressed: _handleSendPressed,
      ),
    );
  }

  @override
  void dispose() {
    socket.close();
    super.dispose();
  }
}
