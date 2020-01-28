import 'package:multi_image/sendOrReceive.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keyboard_visibility/keyboard_visibility.dart';
import 'package:emoji_picker/emoji_picker.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:adhara_socket_io/adhara_socket_io.dart';

const String URI = "http://192.168.29.152:5000/";

void main() => runApp(MaterialApp(
      home: HomePage(),
    ));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File imageFile;
  static const baseUrl = 'http://192.168.29.152:9000';

  SocketIO socket;
  TextEditingController _textEditingController = new TextEditingController();
  ScrollController _scrollController = new ScrollController();
  var sendingMessage;
  bool isEmojiKeyboard = false;
  bool isImageUrl = true;

  var decodedUrl;
  List<SendOrReceive> sentOrReceiveMessages = [];
  List<String> toPrint = ["trying to connect"];
  SocketIOManager manager;
  Map<String, SocketIO> sockets = {};
  Map<String, bool> _isProbablyConnected = {};
  FocusNode myFocusNode;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    manager = SocketIOManager();
    initSocket("default");
    myFocusNode = FocusNode();

    KeyboardVisibilityNotification().addNewListener(
      onChange: (bool visible) {
        if (visible == true) {
          setState(() {
            isEmojiKeyboard = false;
          });
        }
        print('vis $visible');
      },
    );
  }

  _scrollToBottom() {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  initSocket(String identifier) async {
    setState(() => _isProbablyConnected[identifier] = true);
    socket = await manager.createInstance(SocketOptions(
        //Socket IO server URI
        URI,
        nameSpace: (identifier == "namespaced") ? "/adhara" : "/",
        //Query params - can be used for authentication
        query: {
          "auth": "--SOME AUTH STRING---",
          "info": "new connection from adhara-socketio",
          "timestamp": DateTime.now().toString()
        },
        //Enable or disable platform channel logging
        enableLogging: false,
        transports: [
          Transports.WEB_SOCKET, /*Transports.POLLING*/
        ] //Enable required transport
        ));
    socket.onConnect((data) {
      pprint("connected...");
      pprint(data);
//      sendMessage(identifier);
    });
    socket.onConnectError(pprint);
    socket.onConnectTimeout(pprint);
    socket.onError(pprint);
    socket.onDisconnect(pprint);
    socket.on("type:string", (data) => pprint("type:string | $data"));
    socket.on("type:bool", (data) => pprint("type:bool | $data"));
    socket.on("type:number", (data) => pprint("type:number | $data"));
    socket.on("type:object", (data) => pprint("type:object | $data"));
    socket.on("type:list", (data) => pprint("type:list | $data"));
    socket.on("chat", (data) {
      var sendOrReceive = new SendOrReceive();
      sendOrReceive.sentOrReceive = data;
      sentOrReceiveMessages.add(sendOrReceive);
      return pprint(data);
    });
    socket.connect();
    sockets[identifier] = socket;
  }

  bool isProbablyConnected(String identifier) {
    return _isProbablyConnected[identifier] ?? false;
  }

  disconnect(String identifier) async {
    await manager.clearInstance(sockets[identifier]);
    setState(() => _isProbablyConnected[identifier] = false);
  }

  sendMessage(identifier) {
    var sendOrReceive = new SendOrReceive();
    sendOrReceive.sentOrReceive = sendingMessage;
    sendOrReceive.isSend = true;

    if (sockets[identifier] != null) {
      pprint("sending message from '$identifier'...");
      sockets[identifier].emit("chat", [
        sendingMessage,
      ]);
      isImageUrl = sendingMessage.contains('http');
      sentOrReceiveMessages.add(sendOrReceive);
      setState(() {
        sendingMessage = '';
        _textEditingController.clear();
        _scrollToBottom();
      });
      pprint("Message emitted from '$identifier'...");
    }
  }

  sendMessageWithACK(identifier) {
    pprint("Sending ACK message from '$identifier'...");
    List msg = [
      "Hello world!",
      1,
      true,
      {"p": 1},
      [3, 'r']
    ];
    sockets[identifier].emitWithAck("ack-message", msg).then((data) {
      // this callback runs when this specific message is acknowledged by the server
      pprint("ACK recieved from '$identifier' for $msg: $data");
    });
  }

  pprint(data) {
    setState(() {
      if (data is Map) {
        data = json.encode(data);
      }
      print(data);
      toPrint.add(data);
      //receiveMessages.add(data);
    });
  }

  listTile(var sentOrReceiveMessages, int index) {
    if (isImageUrl) {
      return Container(
        decoration: BoxDecoration(
            borderRadius: (index % 2 == 0)
                ? BorderRadius.only(
                    bottomLeft: Radius.circular(10.0),
                    bottomRight: Radius.circular(10.0),
                    topRight: Radius.circular(10.0))
                : BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    bottomLeft: Radius.circular(10.0),
                    bottomRight: Radius.circular(10.0)),
            color: (index % 2 != 0) ? Colors.white : Colors.blue),
        child: Padding(
          padding: const EdgeInsets.only(
              right: 8.0, top: 8.0, bottom: 8.0, left: 8.0),
          child:
              Image.network('http://192.168.29.152:9000/${decodedUrl['url']}'),
        ),
      );
    } else {
      isImageUrl = false;
      return Container(
        decoration: BoxDecoration(
            borderRadius: (index % 2 == 0)
                ? BorderRadius.only(
                    bottomLeft: Radius.circular(10.0),
                    bottomRight: Radius.circular(10.0),
                    topRight: Radius.circular(10.0))
                : BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    bottomLeft: Radius.circular(10.0),
                    bottomRight: Radius.circular(10.0)),
            color: (index % 2 != 0) ? Colors.white : Colors.blue),
        child: Padding(
          padding: const EdgeInsets.only(
              right: 8.0, top: 8.0, bottom: 8.0, left: 8.0),
          child: Text(sentOrReceiveMessages.toString()),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed.
    myFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    bool ipc = isProbablyConnected('default');

    return Scaffold(
      appBar: AppBar(
        title: Text('chat'),
      ),
      body: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 0.0),
            child: Container(
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage('assets/images/wallpaper.png'),
                      fit: BoxFit.cover)),
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 60.0),
                  child:
//                imageFile==null?
                      ListView.builder(
                    shrinkWrap: true,
                    controller: _scrollController,
                    itemCount: sentOrReceiveMessages.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Padding(
                          padding: (index % 2 == 0)
                              ? const EdgeInsets.only(left: 80.0)
                              : const EdgeInsets.only(right: 80.0),
                          child: listTile(
                              sentOrReceiveMessages[index] != null
                                  ? sentOrReceiveMessages[index]
                                  : '',
                              index),
                        ),
                        // When a user taps the ListTile, navigate to the DetailScreen.
                        // Notice that you're not only creating a DetailScreen, you're
                        // also passing the current todo through to it.
                        onTap: () {},
                      );
                    },
                  )
//                    :Column(
//                  children: <Widget>[
//                    Image.file(imageFile, fit: BoxFit.cover),
//
//                  ],
//                ),
                  ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Container(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  height: 60.0,
                  width: MediaQuery.of(context).size.width,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                          icon: Icon(Icons.insert_emoticon),
                          onPressed: () {
                            setState(() {
                              FocusScope.of(context)
                                  .requestFocus(new FocusNode());
                              isEmojiKeyboard = true;
                            });
                          }),
                      IconButton(
                          icon: Icon(Icons.attach_file),
                          onPressed: () {
                            setState(() {
                              FocusScope.of(context)
                                  .requestFocus(new FocusNode());
                              _selectGalleryImage();
                            });
                          }),
                      Expanded(
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: TextField(
                            focusNode: myFocusNode,
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                icon: Icon(Icons.send),
                                onPressed: ipc
                                    ? () {
                                        if (sendingMessage.isNotEmpty) {
                                          FocusScope.of(context)
                                              .requestFocus(myFocusNode);
                                          return sendMessage('default');
                                        }
                                      }
                                    : null,
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0)),
                              hintText: 'Type a message',
                              hintStyle: TextStyle(color: Colors.black26),
                            ),
                            onChanged: (text) {
                              sendingMessage = text;
                            },
                            textInputAction: TextInputAction.send,
                            style: TextStyle(color: Colors.black),
                            controller: _textEditingController,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isEmojiKeyboard == true
                  ? Container(
                      child: EmojiPicker(
                        rows: 3,
                        columns: 7,
                        recommendKeywords: ["racing", "horse"],
                        numRecommended: 10,
                        onEmojiSelected: (emoji, category) {
                          print('EMOJI $emoji');
                          setState(() {
                            sendingMessage =
                                _textEditingController.text += emoji.toString();
                          });
                        },
                      ),
                    )
                  : Container(),
            ],
          ),
        ],
      ),
    );
  }

  _uploadImage() async {
    if (imageFile == null) {
//      return _showSnackbar('Please select image');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return new Center(
          child: new CircularProgressIndicator(),
        );
      },
      barrierDismissible: true,
    );

    try {
      final url = Uri.parse('$baseUrl/upload');
      final fileName = path.basename(imageFile.path);
      final bytes = await compute(compress, imageFile.readAsBytesSync());

      var request = http.MultipartRequest('POST', url)
        ..files.add(
          new http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: fileName,
          ),
        );

      var response = await request.send();
      decodedUrl = await response.stream.bytesToString().then(json.decode);
//      Navigator.pop(context);
      if (response.statusCode == HttpStatus.OK) {
        print('image URL = $baseUrl/${decodedUrl['path']}');
        print('image response = ${decodedUrl['url']}');

        sendingMessage = '$baseUrl/${decodedUrl['path']}';
        sendMessage('default');

//        sendMessage('$baseUrl/${decoded['path']}');
//        _showSnackbar('Image uploaded, imageUrl = $baseUrl/${decoded['path']}');
      } else {
//        _showSnackbar('Image failed: ${decoded['message']}');
      }
    } catch (e) {
      print('e2e $e');
//      Navigator.pop(context);
//      _showSnackbar('Image failed: $e');
    }
  }

  _selectGalleryImage() async {
    imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);
    setState(() {
      _uploadImage();
    });
  }
}

List<int> compress(List<int> bytes) {
  var image = img.decodeImage(bytes);
  var resize = img.copyResize(image, width: 480);
  return img.encodePng(resize, level: 1);
}
