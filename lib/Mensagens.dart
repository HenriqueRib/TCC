import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'model/Conversa.dart';
import 'model/Mensagem.dart';
import 'model/Usuario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound_lite/public/flutter_sound_recorder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audio_recorder/audio_recorder.dart';
import 'package:permission_handler/permission_handler.dart';

class Mensagens extends StatefulWidget {

  Usuario contato;
  Mensagens(this.contato);

  @override
  _MensagensState createState() => _MensagensState();
}

class _MensagensState extends State<Mensagens> {

  bool _subindoImagem = false;
  String _idUsuarioLogado;
  String _idUsuarioDestinatario;
  Firestore db = Firestore.instance;
  TextEditingController _controllerMensagem = TextEditingController();
//Após implementação de gravar
  FocusNode focus = new FocusNode();
  String caminho = "";
  FlutterSoundRecorder myPlayer = FlutterSoundRecorder(); // Instanciando
  FlutterSoundRecorder myRecorder = FlutterSoundRecorder(); // Minha Gravação
  AudioCache audioCache = AudioCache(prefix: "audios/");
  AudioPlayer audioPlayer = AudioPlayer();
  bool primeiraExecucao = true;
  bool _recording = false;

  final _controller = StreamController<QuerySnapshot>.broadcast();
  ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    if (myRecorder != null) {
      myRecorder.closeAudioSession();
      myPlayer = null;
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();
  }

  _enviarMensagem() {

    String textoMensagem = _controllerMensagem.text;
    if (textoMensagem.isNotEmpty) {
      Mensagem mensagem = Mensagem();
      mensagem.idUsuario = _idUsuarioLogado;
      mensagem.mensagem = textoMensagem;
      mensagem.urlImagem = "";
      mensagem.tipo = "texto";
      mensagem.data = Timestamp.now().toString();

      //Salvar mensagem para remetente
      _salvarMensagem(_idUsuarioLogado, _idUsuarioDestinatario, mensagem);

      //Salvar mensagem para o destinatário
      _salvarMensagem(_idUsuarioDestinatario, _idUsuarioLogado, mensagem);

      //Salvar conversa
      _salvarConversa( mensagem );

    }
  }

  _salvarConversa(Mensagem msg){

    //Salvar conversa remetente
    Conversa cRemetente = Conversa();
    cRemetente.idRemetente = _idUsuarioLogado;
    cRemetente.idDestinatario = _idUsuarioDestinatario;
    cRemetente.mensagem = msg.mensagem;
    cRemetente.nome = widget.contato.nome;
    cRemetente.caminhoFoto = widget.contato.urlImagem;
    cRemetente.tipoMensagem = msg.tipo;
    cRemetente.salvar();

    //Salvar conversa destinatario
    Conversa cDestinatario = Conversa();
    cDestinatario.idRemetente = _idUsuarioDestinatario;
    cDestinatario.idDestinatario = _idUsuarioLogado;
    cDestinatario.mensagem = msg.mensagem;
    cDestinatario.nome = widget.contato.nome;
    cDestinatario.caminhoFoto = widget.contato.urlImagem;
    cDestinatario.tipoMensagem = msg.tipo;
    cDestinatario.salvar();

  }

  _salvarMensagem(String idRemetente, String idDestinatario, Mensagem msg) async {
    await db
        .collection("mensagens")
        .document(idRemetente)
        .collection(idDestinatario)
        .add(msg.toMap());

    //Limpa texto
    _controllerMensagem.clear();
  }

  _startRecord() async {
    await Permission.microphone.request().isGranted;
    if (await AudioRecorder.hasPermissions) {
      print("GRAVANDO Algo de errado não esta certo");
    }

    try {
      _recording = true;
      setState(() {});
      final directory = await getApplicationDocumentsDirectory();
      var filename =
          'aud_' + DateTime.now().millisecondsSinceEpoch.toString() + '';
      String path = directory.path + '/' + filename;

      // Check permissions before starting
      bool hasPermissions = await AudioRecorder.hasPermissions;
      // Get the state of the recorder
      bool isRecording = await AudioRecorder.isRecording;
      // Start recording
      print(directory.path);

      await AudioRecorder.start(
          path: path, audioOutputFormat: AudioOutputFormat.AAC);
      print("GRAVANDO ");

    } catch (e) {
      print("GRAVANDO deu Erro");
      print(e.message);
      _recording = false;
      setState(() {});
    }

  }

  _stopRecord() async {
    try {
      _recording = false;
      setState(() {});
      // Stop recording
      Recording recording = await AudioRecorder.stop();
      print(
          "Path : ${recording.path},  Format : ${recording.audioOutputFormat},  Duration : ${recording.duration},  Extension : ${recording.extension},");
      var audio = File(recording.path);
//        uploadFile('audio', audio);
      print("Gravando STOP");
      setState(() {
        caminho = recording.path;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  _executar() async {

//    if( primeiraExecucao ){
//      audioPlayer = await audioCache.play("musica.mp3");
//      primeiraExecucao = false;
//    }else{
//      audioPlayer.resume();
//    }
    await Permission.microphone.request().isGranted;
//    print(await Permission.microphone.request().isGranted);
    if (await AudioRecorder.hasPermissions) {
      print("GRAVANDO Algo de errado não esta certo");
    }


//    _startRecord() async {
    try {
      _recording = true;
      setState(() {});
      final directory = await getApplicationDocumentsDirectory();
      var filename =
          'aud_' + DateTime.now().millisecondsSinceEpoch.toString() + '';
      String path = directory.path + '/' + filename;

      // Check permissions before starting
      bool hasPermissions = await AudioRecorder.hasPermissions;

      // Get the state of the recorder
      bool isRecording = await AudioRecorder.isRecording;
      print("GRAVANDODentro");
      // Start recording
      print(directory.path);

      await AudioRecorder.start(
          path: path, audioOutputFormat: AudioOutputFormat.AAC);
      print("GRAVANDO");

    } catch (e) {
      print("GRAVANDO deu Erro");
      print(e.message);
      _recording = false;
      setState(() {});
    }
//    }


  }
  _pausar() async {
//    int resultado = await audioPlayer.pause();
//    if( resultado == 1 ){
//      //sucesso
//    }

//    _stopRecord() async {
    try {
      _recording = false;
      setState(() {});
      // Stop recording
      Recording recording = await AudioRecorder.stop();
      print(
          "Path : ${recording.path},  Format : ${recording.audioOutputFormat},  Duration : ${recording.duration},  Extension : ${recording.extension},");
      var audio = File(recording.path);
//        uploadFile('audio', audio);
      print("Gravando STOP");
      setState(() {
        caminho = recording.path;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
//    }

  }
  _parar() async {

//    int resultado = await audioPlayer.stop();
//    if( resultado == 1 ){
//      //sucesso
//    }
    if( primeiraExecucao ){
      print("Play antes");
      audioPlayer =  (await audioPlayer.play(caminho, isLocal: true)) as AudioPlayer;
      print("Play depois 1");
//          audioPlayer = (await audioPlayer.play(caminho)) as AudioPlayer;
      primeiraExecucao = false;
    }else{
      audioPlayer.resume();
    }

  }

  // ainda não envia
  _enviarAudio() async {
//    audioPlayer = await audioCache.play("musica.mp3");
    showDialog (
        context: context,
        builder:(context){
          return
            Padding(
              padding: EdgeInsets.fromLTRB(0,400,0,0),
              child: AlertDialog(
                title: Text("Grave e envie seu audio!"),
                content: Column(
                  children: <Widget>[
                    //Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[

                        Padding(
                          padding: EdgeInsets.all(12),
                          child: GestureDetector(
                            child: Icon(Icons.mic),
                            onTap: (){
                              _executar();
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: GestureDetector(
                            child: Icon(Icons.stop),
                            onTap: (){
                              _pausar();
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: GestureDetector(
                            child: Icon(Icons.play_arrow),
                            onTap: (){
                              _parar();
                            },
                          ),
                        )

                      ],
                    )
                  ],
                ),
              ),
            );

        }
    );
  }

  _enviarFoto() async {

    File imagemSelecionada;
    imagemSelecionada = await ImagePicker.pickImage(source: ImageSource.gallery);

    _subindoImagem = true;
    String nomeImagem = DateTime.now().millisecondsSinceEpoch.toString();
    FirebaseStorage storage = FirebaseStorage.instance;
    StorageReference pastaRaiz = storage.ref();
    StorageReference arquivo = pastaRaiz
        .child("mensagens")
        .child( _idUsuarioLogado )
        .child( nomeImagem + ".jpg");

    //Upload da imagem
    StorageUploadTask task = arquivo.putFile( imagemSelecionada );

    //Controlar progresso do upload
    task.events.listen((StorageTaskEvent storageEvent){

      if( storageEvent.type == StorageTaskEventType.progress ){
        setState(() {
          _subindoImagem = true;
        });
      }else if( storageEvent.type == StorageTaskEventType.success ){
        setState(() {
          _subindoImagem = false;
        });
      }

    });

    //Recuperar url da imagem
    task.onComplete.then((StorageTaskSnapshot snapshot){
      _recuperarUrlImagem(snapshot);
    });

  }

  _recuperarDadosUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    _idUsuarioLogado = usuarioLogado.uid;
    _idUsuarioDestinatario = widget.contato.idUsuario;

    _adicionarListenerMensagens();

  }

  Future _recuperarUrlImagem(StorageTaskSnapshot snapshot) async {

    String url = await snapshot.ref.getDownloadURL();

    Mensagem mensagem = Mensagem();
    mensagem.idUsuario = _idUsuarioLogado;
    mensagem.mensagem = "";
    mensagem.urlImagem = url;
    mensagem.tipo = "imagem";
    mensagem.data = Timestamp.now().toString();

    //Salvar mensagem para remetente
    _salvarMensagem(_idUsuarioLogado, _idUsuarioDestinatario, mensagem);

    //Salvar mensagem para o destinatário
    _salvarMensagem(_idUsuarioDestinatario, _idUsuarioLogado, mensagem);

  }

  Stream<QuerySnapshot> _adicionarListenerMensagens(){

    final stream = db.collection("mensagens")
        .document(_idUsuarioLogado)
        .collection(_idUsuarioDestinatario)
        .orderBy("data", descending: false)
        .snapshots();

    stream.listen((dados){
      _controller.add( dados );
      Timer(Duration(seconds: 1), (){
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } );
    });

  }

  @override
  Widget build(BuildContext context) {

    var caixaMensagem = Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: TextField(
                controller: _controllerMensagem,
                focusNode: focus,
                keyboardType: TextInputType.text,
                style: TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(32, 8, 32, 8),
                  hintText: "Digite uma mensagem...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32)),
//                    prefixIcon:
                  suffixIcon:
                  _subindoImagem
                      ? CircularProgressIndicator()
//                        : IconButton(icon: Icon(Icons.camera_alt),onPressed: _enviarFoto),
                      : IconButton(icon: Icon(Icons.camera_alt),onPressed: _enviarAudio),
                  prefixIcon:
                  _subindoImagem
                      ? CircularProgressIndicator()
                      : IconButton(icon: Icon(Icons.mic),onPressed: _enviarAudio),
//                      : GestureDetector (
//                    onLongPressStart: (details) {
//                      print("DEDO EM CIMA");
//                      _startRecord();
//                    },
//                    onLongPressEnd: (details) async {
//                      print("DEDO saiu");
//                      await Future.delayed(
//                          Duration(seconds: 1));
//                      _stopRecord();
//                    },child: Stack(
//                    overflow: Overflow.visible,
//                    children: [
//                      !_recording
//                          ? Container()
//                          : Positioned(
//                        bottom: -50,
//                        right: -50,
//                        child: Container(
//                          width: 150,
//                          height: 150,
//                          decoration: BoxDecoration(
//                              borderRadius:
//                              BorderRadius
//                                  .circular(
//                                  360),
//                              color: Color(0xff2A5E8e)),
//                        ),
//                      ),
//                      IconButton(
//                          icon: Icon(
//                            Icons.mic,
//                            color: _recording
//                                ? Colors.red
//                                : Colors.black,
//                          ),
//                          onPressed: () {},
//                          color: Color(0xff2A5E8e)
//                      ),
//                    ],
//                  ),
//                  ),
                ),
              ),
            ),
          ),
          Platform.isIOS
              ? CupertinoButton(
            child: Text("Enviar"),
            onPressed: _enviarMensagem,
          )
              : FloatingActionButton(
            backgroundColor: Color(0xff2A5E8e),
            child: Icon(
              Icons.send,
              color: Colors.white,
            ),
            mini: true,
            onPressed: _enviarMensagem,
          )
        ],
      ),
    );

    var stream = StreamBuilder(
      stream: _controller.stream,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return Center(
              child: Column(
                children: <Widget>[
                  Text("Carregando mensagens"),
                  CircularProgressIndicator()
                ],
              ),
            );
            break;
          case ConnectionState.active:
          case ConnectionState.done:

            QuerySnapshot querySnapshot = snapshot.data;

            if (snapshot.hasError) {
              return Text("Erro ao carregar os dados!");
            } else {
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (){
                    focus.unfocus();
                  },
                  child: ListView.builder(
                      controller: _scrollController,
                      itemCount: querySnapshot.documents.length,
                      itemBuilder: (context, indice) {

                        //recupera mensagem
                        List<DocumentSnapshot> mensagens = querySnapshot.documents.toList();
                        DocumentSnapshot item = mensagens[indice];

                        double larguraContainer =
                            MediaQuery.of(context).size.width * 0.8;

                        //Define cores e alinhamentos
                        Alignment alinhamento = Alignment.centerRight;
                        Color cor = Color(0xffd2ffa5);
                        if ( _idUsuarioLogado != item["idUsuario"] ) {
                          alinhamento = Alignment.centerLeft;
                          cor = Colors.white;
                        }

                        return Align(
                          alignment: alinhamento,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Container(
                              width: larguraContainer,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: cor,
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(8))),
                              child:
                              item["tipo"] == "texto"
                                  ? Text(item["mensagem"],style: TextStyle(fontSize: 18),)
                                  : Image.network(item["urlImagem"]),
                            ),
                          ),
                        );
                      }),
                ),
              );
            }
            break;
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            CircleAvatar(
                maxRadius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: widget.contato.urlImagem != null
                    ? NetworkImage(widget.contato.urlImagem)
                    : null),
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(widget.contato.nome),
            )
          ],
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("imagens/bg.png"), fit: BoxFit.cover)),
        child: SafeArea(
            child: Container(
              padding: EdgeInsets.all(8),
              child: Column(
                children: <Widget>[
                  stream,
                  caixaMensagem,
                ],
              ),
            )),
      ),
    );
  }
}
