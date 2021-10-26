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

  bool primeiraExecucao = true;
  bool _subindoImagem = false;
  bool _recording = false;
  bool _btnEnviar = false;
  bool _subindoAudio = false;
  bool tocando = false;
  bool pause = false;
  bool bgControle = false;
  String _tempoupload;
  String _idUsuarioLogado;
  String _fotoUsuarioLogado;
  String _fotoAudio;
  String _idUsuarioDestinatario;
  String caminho = "";
  String _bg = "imagens/bg.png";
  int possition = 0;
  int idTocando = 0;
  var speed = 1.0;
  var duracao_total ;
  var indiceAtual;
  TextEditingController _controllerMensagem = TextEditingController();
  AudioCache audioCache = AudioCache(prefix: "audios/");
  AudioPlayer audioPlayer = AudioPlayer();
  FocusNode focus = new FocusNode();
  Firestore db = Firestore.instance;

  final _controller = StreamController<QuerySnapshot>.broadcast();
  ScrollController _scrollController = ScrollController();

  @override
  void dispose() async {
    if (tocando == true) {
      await audioPlayer.stop();
      tocando = false;
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
      focus.unfocus(); // fecha o teclado
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
      var tempo = recording.duration;
      _uploadFile( audio, tempo );
      print("Gravando STOP");
      setState(() {
        caminho = recording.path;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  _playRecord(time, indice) async {

    if( primeiraExecucao == true && pause == false ){
//      audioPlayer = (await audioPlayer.play(caminho, isLocal: true)) as AudioPlayer;

      await audioPlayer.play(caminho,isLocal: true);
      await audioPlayer.setPlaybackRate(playbackRate: speed);

      primeiraExecucao = false;
      print("Audio Executando");
      setState(() {
        _bg = "imagens/bg1.png";
        tocando = true;
        idTocando = indice;
        indiceAtual = indice;
      });
    }else{
      print("Resume Audio");
      print('indiceAtual -> $indiceAtual iNDICE -> $indice');
      if (indiceAtual == indice){
        await audioPlayer.resume();
      }

      await audioPlayer.play(caminho,isLocal: true);
      await audioPlayer.setPlaybackRate(playbackRate: speed);

      if(bgControle == false){
        setState(() {
          _bg = "imagens/bg1.png";
        });
      }
      setState(() {
        tocando = true;
        idTocando = indice;
      });
      primeiraExecucao = true;
    }

    duracao_total = parseDuration(time) ;

    audioPlayer.onAudioPositionChanged.listen((Duration  p)  {
      possition = p.inSeconds;
      print('Possition -> $possition Current position: $p');

        if(possition > (duracao_total.inSeconds * 0.5).floor())
        {
          setState(() {
            bgControle = true;
            _bg = "imagens/bg2.png";
          });
        }

        if(possition > (duracao_total.inSeconds * 0.75).floor() )
        {
          setState(() {
            _bg = "imagens/bg3.png";
          });
        }

    });

    //Funciona apenas quando termina o audio
    audioPlayer.onPlayerCompletion.listen((event) {
      setState(() {
         possition = 0;
         duracao_total = 0;
         speed = 1.0;
         tocando = false;
         pause = false;
         bgControle = false;
         _bg = "imagens/bg.png";
         primeiraExecucao = true;
      });
    });

  }

  _stopAudio() async{
      await audioPlayer.pause();
      setState(() {
        _bg = "imagens/bg.png";
        tocando = false;
        pause = true;
        idTocando = 0;
      });
  }

  _verifica(){
    _controllerMensagem.text.isEmpty ? _btnEnviar = true :  _btnEnviar = false;
    return _btnEnviar;
  }

  _uploadFile(audio , tempo){

    _subindoAudio = true;
    String nomeAudio = DateTime.now().millisecondsSinceEpoch.toString();
    FirebaseStorage storage = FirebaseStorage.instance;
    StorageReference pastaRaiz = storage.ref();
    StorageReference arquivo = pastaRaiz
        .child("mensagens")
        .child( _idUsuarioLogado )
        .child( nomeAudio );

    //Upload do audio
    StorageUploadTask task = arquivo.putFile( audio );

    //Controlar progresso do upload
    task.events.listen((StorageTaskEvent storageEvent){

      if( storageEvent.type == StorageTaskEventType.progress ){
        setState(() {
          _subindoAudio = true;
        });
      }else if( storageEvent.type == StorageTaskEventType.success ){
        setState(() {
          _subindoAudio = false;
        });
      }
    });

    // Atualizando tempo para salvar
    setState(() {
      _tempoupload = tempo.toString();
    });

    //Recuperar url do Audio
    task.onComplete.then((StorageTaskSnapshot snapshot){
      _recuperarUrlAudio(snapshot);
    });

  }

  Duration parseDuration(String s) {
    int hours = 0;
    int minutes = 0;
    int micros;
    List<String> parts = s.split(':');
    if (parts.length > 2) {
      hours = int.parse(parts[parts.length - 3]);
    }
    if (parts.length > 1) {
      minutes = int.parse(parts[parts.length - 2]);
    }
    micros = (double.parse(parts[parts.length - 1]) * 1000000).round();
    return Duration(hours: hours, minutes: minutes, microseconds: micros);
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

    //Recupera Foto Perfil Usuario
    final stream = db.collection("usuarios")
        .document( _idUsuarioLogado )
        .snapshots();
    stream.listen((dados){
      _fotoUsuarioLogado = dados.data['urlImagem'];
    });
    //Finaliza recupera Foto Perfil usuario

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

  Future _recuperarUrlAudio(StorageTaskSnapshot snapshot) async {

    String url = await snapshot.ref.getDownloadURL();

    Mensagem mensagem = Mensagem();
    mensagem.idUsuario = _idUsuarioLogado;
    mensagem.mensagem = _tempoupload;
    mensagem.urlImagem = url;
    mensagem.tipo = "audio";
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
                onChanged: (_){
                  setState(() {
                    _verifica();
                  });
                },
                focusNode: focus,
                keyboardType: TextInputType.text,
                style: TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(25, 8, 5, 8),
                  hintText: "Digite uma mensagem ...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32)),
                  suffixIcon:
                  _subindoImagem
                      ? CircularProgressIndicator()
                      : IconButton(icon: Icon(Icons.camera_alt),onPressed: _enviarFoto),
//                      : IconButton(icon: Icon(Icons.camera_alt),onPressed: _caixaDialogo),
                ),
              ),
            ),
          ),
          Platform.isIOS
              ? CupertinoButton(
            child: Text("Enviar"),
            onPressed: _enviarMensagem,
          )
              : _verifica() ? GestureDetector (
                    onLongPressStart: (details) {
                      print("DEDO EM CIMA");
                      _startRecord();
                    },
                    onLongPressEnd: (details) async {
                      print("DEDO saiu");
                      await Future.delayed(
                          Duration(seconds: 1));
                      _stopRecord();
                    },child: Stack(
                    overflow: Overflow.visible,
                    children: [
                      !_recording
                          ? Container()
                          : Positioned(
                        bottom: -50,
                        right: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  360),
                              color: Color(0xff2A5E8e)),
                        ),
                      ),
                      _subindoAudio
                          ? CircularProgressIndicator() :
                      IconButton(
                          icon: Icon(
                            Icons.mic,
                            color: _recording
                                ? Colors.red
                                : Color(0xff2A5E8e),
                          ),
                          onPressed: () {},
                          color: Color(0xff2A5E8e)
                      ),
                    ],
                  ),
              ) :
          FloatingActionButton(
            backgroundColor: Color(0xff2A5E8e),
            child: Icon(
              Icons.send,
              color: Colors.white,
            ),
            mini: true,
            onPressed: _enviarMensagem,
          ),

        ],
      ),
    );

    var stream = StreamBuilder(
      stream: _controller.stream,
      // ignore: missing_return
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
                        _fotoAudio = _fotoUsuarioLogado;
                        if ( _idUsuarioLogado != item["idUsuario"] ) {
                          alinhamento = Alignment.centerLeft;
                          cor = Colors.white;
                          _fotoAudio = widget.contato.urlImagem ;
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
                                  : item["tipo"] == "imagem"
                                  ? Image.network(item["urlImagem"])
                                  : Row(
                                children: <Widget>[
                                  tocando && idTocando == indice ?
                                      speed == 1.0 ?
                                  CircleAvatar(
                                      maxRadius: 30,
                                      backgroundColor: Color(0xff2A5E8e),
                                      child: GestureDetector(
                                        onTap: (){
                                          setState(() {
                                              speed = 2.0;
                                              audioPlayer.setPlaybackRate(playbackRate: speed );
                                            });
                                          },
                                        child: Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          child: Center(
                                            child: Text("1x",
                                                style: TextStyle(
                                                fontSize: 35,
                                                fontStyle: FontStyle.normal,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0,
                                                wordSpacing: 0,
                                                decoration: TextDecoration.none,
                                                color: Colors.white
                                              ),
                                            )
                                          )
                                        ),
                                      )
                                  )
                                      :
                                  speed == 2.0 ?
                                      CircleAvatar(
                                          maxRadius: 30,
                                          backgroundColor: Color(0xff2A5E8e),
                                          child: GestureDetector(
                                            onTap: (){
                                              setState(() {
                                                speed = 5.0;
                                                audioPlayer.setPlaybackRate(playbackRate: speed );
                                              });
                                            },
                                            child: Container(
                                                width: double.infinity,
                                                height: double.infinity,
                                                child: Center(
                                                    child: Text("2x",
                                                    style: TextStyle(
                                                        fontSize: 35,
                                                        fontStyle: FontStyle.normal,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0,
                                                        wordSpacing: 0,
                                                        decoration: TextDecoration.none,
                                                        color: Colors.white
                                                    ),
                                                  )
                                                )
                                            ),
                                          )
                                      )
                                   :
                                  CircleAvatar(
                                      maxRadius: 30,
                                      backgroundColor: Color(0xff2A5E8e),
                                      child: GestureDetector(
                                        onTap: (){
                                          setState(() {
                                            speed = 1.0;
                                            audioPlayer.setPlaybackRate(playbackRate: speed );
                                          });
                                        },
                                        child: Container(
                                            width: double.infinity,
                                            height: double.infinity,
                                            child: Center(
                                                child: Text("5x",
                                                style: TextStyle(
                                                    fontSize: 35,
                                                    fontStyle: FontStyle.normal,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0,
                                                    wordSpacing: 0,
                                                    decoration: TextDecoration.none,
                                                    color: Colors.white
                                                ),
                                              )
                                            )
                                        ),
                                      )
                                  )
                                      :
                                  CircleAvatar(
                                      maxRadius: 30,
                                      backgroundColor: Colors.grey,
                                      backgroundImage: NetworkImage(_fotoAudio)
                                  ),
                                  tocando && idTocando == indice ?
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: IconButton(
                                      icon: Icon(Icons.pause, size: 40,),
                                      onPressed: () {
                                        _stopAudio();
                                      },
                                    ),
                                  )
                                      :
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: IconButton(
                                      icon: Icon(Icons.play_arrow, size: 40,),
                                      onPressed: () {
                                        setState(() {
                                          caminho = item["urlImagem"];
                                        });
                                        _playRecord(item["mensagem"], indice);
                                      },
                                    ),
                                  ),
                                  tocando && idTocando == indice ?
                                  Container(
                                    constraints: BoxConstraints(maxWidth: 140),
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text("Aperte pause para pausar" ,
                                          maxLines: 2),
                                    ),
                                  )
                                  :
                                  Container(
                                    constraints: BoxConstraints(maxWidth: 140),
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text("Aperte play para ouvir" ,
                                          maxLines: 2),
                                    ),
                                  )
                                ],
                              ),
//                              Text(item["mensagem"],style: TextStyle(fontSize: 18),),
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
              child: Text(widget.contato.nome ),
            )
          ],
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage(_bg), fit: BoxFit.cover)),
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
