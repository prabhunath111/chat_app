import 'package:multi_image/sendOrReceive.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
// import 'package:image/image.dart' as img;
// import 'package:image/image.dart';
import 'package:image_picker/image_picker.dart' as img;
import 'dart:io';
import 'package:keyboard_visibility/keyboard_visibility.dart';
import 'package:emoji_picker/emoji_picker.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:adhara_socket_io/adhara_socket_io.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'package:flutter/services.dart';


void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
      home: HomePage(),
    ));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ProgressDialog pr;
  File imageFile;
//  static const String URI = "http://192.168.29.152:5000/";
//  static const baseUrl = 'http://192.168.29.152:9000';

  static const String URI = "https://prabhu-socket.herokuapp.com/";
  static const baseUrl = 'https://prabhu-file.herokuapp.com';

  SocketIO socket;
  TextEditingController _textEditingController = new TextEditingController();
  ScrollController _scrollController = new ScrollController();
  var sendingMessage;
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
            SendOrReceive.isEmoji = false;
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
      var a = sentOrReceiveMessages.last;
      print(("check a: ${a.sentOrReceive}"));
      sendOrReceive.sentOrReceive = data;
      sendOrReceive.isFileReceive = data.contains('http');

//      sendOrReceive.isSend = false;
     /*
     I am comparing here last msg in db and coming msg from server, is both are same it will not be added
      This is not a good way but it's temporary ok, i have to fix it ASAP.
      */
      sentOrReceiveMessages.add((a.sentOrReceive==sendOrReceive.sentOrReceive)?'':sendOrReceive);
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
    sendOrReceive.isFile = sendingMessage.contains('http');

    if (sockets[identifier] != null) {
      pprint("sending message from '$identifier'...");
      sockets[identifier].emit("chat", [
        sendingMessage,
      ]);
      sentOrReceiveMessages.add(sendOrReceive);
      setState(() {
        sendingMessage = '';
        _textEditingController.clear();
        _scrollToBottom();
      });
      pprint("Message emitted from '$identifier'...");
    }
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
    if (sentOrReceiveMessages.isFile) {
      return Padding(
        padding: (sentOrReceiveMessages.isFileReceive)
            ? EdgeInsets.only(right: 80.0)
            : EdgeInsets.only(left: 80.0),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: (sentOrReceiveMessages.isFile)
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(10.0),
                      bottomRight: Radius.circular(10.0),
                      topRight: Radius.circular(10.0))
                  : BorderRadius.only(
                      topLeft: Radius.circular(10.0),
                      bottomLeft: Radius.circular(10.0),
                      bottomRight: Radius.circular(10.0)),
              color:
                  (sentOrReceiveMessages.isSend) ? Colors.blue : Colors.white),
          child: Padding(
            padding: const EdgeInsets.only(
                right: 8.0, top: 8.0, bottom: 8.0, left: 8.0),
            child: Stack(
              children: <Widget>[
                Container(
                  margin: EdgeInsets.all(16.0),
                  child: Center(
                      child: CircularProgressIndicator(
                    strokeWidth: 4.0,
                    value: 20.0,
                    backgroundColor: Colors.grey,
                  )),
                ),
                Center(
                    child: Image.network(
                        'https://prabhu-file.herokuapp.com/${decodedUrl['url']}')),
              ],
            ),

//           Container(child: Image.network('http://192.168.29.152:9000/${decodedUrl['url']}')),
          ),
        ),
      );
    } else if (sentOrReceiveMessages.isFileReceive) {
      return Padding(
        padding: (sentOrReceiveMessages.isFileReceive)
            ? EdgeInsets.only(right: 80.0)
            : EdgeInsets.only(left: 80.0),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: (sentOrReceiveMessages.isFile)
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(10.0),
                      bottomRight: Radius.circular(10.0),
                      topRight: Radius.circular(10.0))
                  : BorderRadius.only(
                      topLeft: Radius.circular(10.0),
                      bottomLeft: Radius.circular(10.0),
                      bottomRight: Radius.circular(10.0)),
              color:
                  (sentOrReceiveMessages.isSend) ? Colors.blue : Colors.white),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child:
            Stack(
              children: <Widget>[
                Container(
                  margin: EdgeInsets.all(16.0),
                  child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 4.0,
                        value: 20.0,
                        backgroundColor: Colors.grey,
                      )),
                ),
                Center(
                    child: Image.network(
                        'https://prabhu-file.herokuapp.com/${decodedUrl['url']}')),
              ],
            ),
//            Image.network(
//                'http://192.168.29.152:9000/${decodedUrl['url']}'),
          ),
        ),
      );
    } else {
      return Padding(
        padding: (sentOrReceiveMessages.isSend)
            ? EdgeInsets.only(left: 80.0)
            : EdgeInsets.only(right: 80.0),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: (sentOrReceiveMessages.isSend)
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(10.0),
                      bottomRight: Radius.circular(10.0),
                      topRight: Radius.circular(10.0))
                  : BorderRadius.only(
                      topLeft: Radius.circular(10.0),
                      bottomLeft: Radius.circular(10.0),
                      bottomRight: Radius.circular(10.0)),
              color:
                  (sentOrReceiveMessages.isSend) ? Colors.blue : Colors.white),
          child: Padding(
            padding: const EdgeInsets.only(
                right: 8.0, top: 8.0, bottom: 8.0, left: 8.0),
            child:
            Text(sentOrReceiveMessages.sentOrReceive),
          ),
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
        title: Text('prabhu chat'),
        /*actions: <Widget>[
          PopupMenuButton<String>(
            offset: Offset(0.0, 60.0),
            onSelected: choiceAction,
            itemBuilder: (BuildContext context){
              return Constants.choices.map((String choice){
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          )
        ],*/
      ),
      body: new GestureDetector(
        onTap: (){
          setState(() {
            SendOrReceive.isEmoji = false ;
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          });
        },
        child: Stack(
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      controller: _scrollController,
                      itemCount: sentOrReceiveMessages.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: listTile(
                              sentOrReceiveMessages[index] != null
                                  ? sentOrReceiveMessages[index]
                                  : '',
                              index),

                          onTap: () {

                          },
                          onLongPress: (){
                            var alertDialog = AlertDialog(
                              title: Text("want delete"),
                              content: Text("Sure!"),
                            );
                            showDialog(
                                context: context,
                                builder: (BuildContext context) => alertDialog);
                          },
                        );
                      },
                    )),
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
                                FocusScope.of(context).requestFocus(new FocusNode());
                                SendOrReceive.isEmoji = true ;
                              });
                            }),
                        /*IconButton(
                            icon: Icon(Icons.attach_file),
                            onPressed: () {
                              setState(() {
                                FocusScope.of(context)
                                    .requestFocus(new FocusNode());
                                _selectGalleryImage();
                              });
                            }),*/
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
                                            setState(() {
                                              FocusScope.of(context).requestFocus(myFocusNode);
                                              SystemChannels.textInput.invokeMethod('TextInput.hide');

                                              return sendMessage('default');
                                            });
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
                SendOrReceive.isEmoji == true
                    ? Container(
                        child: EmojiPicker(
                          rows: 3,
                          columns: 7,
                          recommendKeywords: ["racing", "horse"],
                          numRecommended: 10,
                          onEmojiSelected: (emoji, category) {
                            print('EMOJI ${emoji.emoji}');
                            setState(() {
                              sendingMessage =
                                  _textEditingController.text += emoji.emoji.toString();
                            });
                          },
                        ),
                      )
                    : Container(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /*_uploadImage() async {
    if (imageFile == null) {
//      return _showSnackbar('Please select image');
      return;
    }

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
  }*/

  /*_selectGalleryImage() async {
    imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);
    setState(() {
      _uploadImage();
    });
  }*/

  /*void choiceAction(String choice) {
    if(choice == Constants.settings){
      print('Settings');
    }else if(choice == Constants.subscribe){
      print('Subscribe');
    }else if(choice == Constants.signOut){
      print('SignOut');
    }
  }*/
}

/*
List<int> compress(List<int> bytes) {
  var image = img.decodeImage(bytes);
  var resize = img.copyResize(image, width: 480);
  return img.encodePng(resize, level: 1);
}
*/
