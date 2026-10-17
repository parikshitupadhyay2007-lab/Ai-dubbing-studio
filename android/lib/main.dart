import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// Emulator: 10.0.2.2. Physical phone: replace with your computer's LAN IP.
const server = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
void main() => runApp(const Studio());
class Studio extends StatelessWidget {
 const Studio({super.key});
 @override Widget build(BuildContext context) => MaterialApp(title:'AI Dubbing Studio',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:Colors.deepPurple),home:const Home());
}
class Home extends StatefulWidget {const Home({super.key}); @override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home> {
 Map<String,dynamic>? project; bool busy=false; String status=''; String language='hi',style='natural'; final Map<String,String> voices={}; final Map<int,TextEditingController> translations={}; final Map<int,TextEditingController> speakers={};
 List<Map<String,dynamic>> get segments => ((project?['segments']??[]) as List).cast<Map<String,dynamic>>();
 List<String> get voiceOptions => language=='hi'?['hi-IN-MadhurNeural','hi-IN-SwaraNeural']:(style=='natural'?['en-US-GuyNeural','en-US-JennyNeural','en-US-AriaNeural']:['en-US-ChristopherNeural','en-US-AriaNeural','en-US-DavisNeural']);
 Future<void> upload() async {
 final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['mp4','mkv','mov','webm','mp3','wav','m4a']);
 if(result==null || result.files.single.path==null)return;
 setState(() {busy=true;status='Uploading and transcribing. This may take several minutes...';});
 try {
 final req=http.MultipartRequest('POST',Uri.parse('$server/projects'))..files.add(await http.MultipartFile.fromPath('file',result.files.single.path!));
 final res=await http.Response.fromStream(await req.send()); if(res.statusCode!=200)throw Exception(res.body);
 final data=jsonDecode(res.body) as Map<String,dynamic>;
 for(final c in translations.values){c.dispose();} for(final c in speakers.values){c.dispose();} translations.clear();speakers.clear();voices.clear();
 for(final s in (data['segments'] as List)) {final id=s['id'] as int;translations[id]=TextEditingController(text:s['translation']??'');speakers[id]=TextEditingController(text:s['speaker']);}
 setState(() {project=data;status='Transcription complete. Review speaker names and enter translated dialogue.';});
 }catch(e){setState(()=>status='Error: $e');}finally{setState(()=>busy=false);}
 }
 Future<void> render() async {
 setState(() {busy=true;status='Generating character voices and video...';});
 try {
 final edited=segments.map((s)=>{...s,'speaker':speakers[s['id']]!.text.trim(),'translation':translations[s['id']]!.text.trim()}).toList();
 final names=edited.map((s)=>s['speaker'] as String).toSet();
 for(final name in names){if(name.isEmpty)throw Exception('Speaker names cannot be empty');voices.putIfAbsent(name,()=>voiceOptions[names.toList().indexOf(name)%voiceOptions.length]);}
 final res=await http.post(Uri.parse('$server/projects/${project!['id']}/render'),headers:{'Content-Type':'application/json'},body:jsonEncode({'language':language,'style':style,'segments':edited,'voices':voices}));
 if(res.statusCode!=200)throw Exception(res.body);
 final video=await http.get(Uri.parse('$server/projects/${project!['id']}/download'));if(video.statusCode!=200)throw Exception('Download failed');
 final dir=await getApplicationDocumentsDirectory();final file=File('${dir.path}/AI-Dubbing-Studio-${project!['id']}.mp4');await file.writeAsBytes(video.bodyBytes);
 setState(()=>status='Saved: ${file.path}');await OpenFilex.open(file.path);
 }catch(e){setState(()=>status='Error: $e');}finally{setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){
 final names=segments.map((s)=>speakers[s['id']]?.text.trim()??'').where((s)=>s.isNotEmpty).toSet().toList();
 return Scaffold(appBar:AppBar(title:const Text('AI Dubbing Studio')),body:ListView(padding:const EdgeInsets.all(16),children:[
 const Text('Every Character. Every Language.',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:16),
 FilledButton.icon(onPressed:busy?null:upload,icon:const Icon(Icons.video_file),label:const Text('Upload video or audio')),
 if(busy)const LinearProgressIndicator(),Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(status)),
 if(project!=null)...[
 Text('Detected original language: ${project!['source_language']}'),
 const SizedBox(height:12),DropdownButtonFormField<String>(value:language,decoration:const InputDecoration(labelText:'Dub language'),items:const [DropdownMenuItem(value:'hi',child:Text('Hindi')),DropdownMenuItem(value:'en',child:Text('English'))],onChanged:busy?null:(v)=>setState((){language=v!;voices.clear();})),
 const SizedBox(height:12),DropdownButtonFormField<String>(value:style,decoration:const InputDecoration(labelText:'Voice style'),items:const [DropdownMenuItem(value:'natural',child:Text('Natural')),DropdownMenuItem(value:'expressive',child:Text('Expressive'))],onChanged:busy?null:(v)=>setState((){style=v!;voices.clear();})),
 const SizedBox(height:18),const Text('1. Edit character labels and target-language dialogue',style:TextStyle(fontWeight:FontWeight.bold)),
 ...segments.map((s)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['start']}s 鈥� ${s['end']}s  鈥�  Original: ${s['text']}'),TextField(controller:speakers[s['id']],decoration:const InputDecoration(labelText:'Character / speaker'),onChanged:(_)=>setState((){})),TextField(controller:translations[s['id']],decoration:const InputDecoration(labelText:'Translated dialogue (Hindi or English)'),maxLines:2)])))),
 const SizedBox(height:16),const Text('2. Assign a distinct voice to each character',style:TextStyle(fontWeight:FontWeight.bold)),
 ...names.map((name){final selected=voices[name];final value=voiceOptions.contains(selected)?selected:voiceOptions[names.indexOf(name)%voiceOptions.length];voices[name]=value;return DropdownButtonFormField<String>(key:ValueKey('$name-$language-$style'),value:value,decoration:InputDecoration(labelText:name),items:voiceOptions.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>voices[name]=v!));}),
 const SizedBox(height:18),FilledButton.icon(onPressed:busy?null:render,icon:const Icon(Icons.movie_creation_outlined),label:const Text('Generate dubbed MP4')),
 const Text('MVP: dialogue-only output. Please use media you own or are authorized to dub.',style:TextStyle(fontSize:12)),
 ]
 ]));
 }
 @override void dispose(){for(final c in translations.values){c.dispose();}for(final c in speakers.values){c.dispose();}super.dispose();}
}
