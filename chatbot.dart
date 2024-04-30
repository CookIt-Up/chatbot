import 'package:dialog_flowtter/dialog_flowtter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'Messages.dart';

class ChatbotApp extends StatelessWidget {
  const ChatbotApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatBot',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late DialogFlowtter dialogFlowtter;
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> messages = [];

  void initState() {
    DialogFlowtter.fromFile().then((instance) => dialogFlowtter = instance);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFD1E7D2),
      body: Container(
        child: Column(
          children: [
            Expanded(child: MessagesScreen(messages: messages)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Color.fromARGB(255, 71, 119, 74),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                          color: const Color.fromARGB(255, 76, 76, 76)),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      sendMessage(_controller.text);
                      _controller.clear();
                    },
                    icon: Icon(Icons.send),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  sendMessage(String text) async {
    if (text.isEmpty) {
      print('Message is empty');
    } else {
      setState(() {
        addMessage(Message(text: DialogText(text: [text])), true);
      });

      // Check if the message contains "okay" or "ok"
      if (text.toLowerCase().contains('okay') ||
          text.toLowerCase().contains('ok')) {
        // Ask for the target calories
        setState(() {
          addMessage(
              Message(
                  text: DialogText(text: [
                'Sure! What is your desired target calories for the meal plan?'
              ])),
              false);
        });
      } else {
        // Check if the message contains a number
        final containsNumber = RegExp(r'\b\d+\b').hasMatch(text);
        if (containsNumber) {
          // Extract the number from the text
          final extractedNumber = double.tryParse(text);
          if (extractedNumber != null) {
            setState(() {
              addMessage(
                  Message(
                      text: DialogText(text: [
                    'Would you like the meal plan for a day or a week?'
                  ])),
                  false);
            });
            //fetchSpoonacularData('', extractedNumber);
          } else {
            // If parsing fails, continue with Dialogflow
            await fetchDialogFlowResponse(text);
          }
        } else {
          // Check if the message is "day" or "week"
          final lowerCaseText = text.trim().toLowerCase();
          if (lowerCaseText == 'day' || lowerCaseText == 'week') {
            handleUserInput(lowerCaseText);
          } else {
            // If the message is neither a number, "day", nor "week", continue with Dialogflow
            await fetchDialogFlowResponse(text);
          }
        }
      }
    }
  }

  Future<void> handleUserInput(String response) async {
    String timeFrame = '';

    // Convert the response to lowercase for consistency
    final lowerCaseResponse = response.toLowerCase();

    if (lowerCaseResponse == 'day' || lowerCaseResponse == 'week') {
      // If the response is "day" or "week", store it in the timeFrame variable
      timeFrame = lowerCaseResponse;

      // Fetch meals based on the selected time frame
      await fetchSpoonacularData(timeFrame, null);
    } else {
      // If the response is neither "day" nor "week", inform the user that the response is invalid
      addMessage(
        Message(
            text: DialogText(
                text: ['Invalid response. Please choose "day" or "week".'])),
        false,
      );
    }
  }

  Future<void> fetchSpoonacularData(
      String timeFrame, double? extractedNumber) async {
    try {
      final String apiKey =
          'ff15ea2a66ad401ab0aa564496ceaaa6'; // Replace with your Spoonacular API key
      final int maxFat = 25;
      print(extractedNumber);
      final response = await http.get(
        Uri.parse(
          'https://api.spoonacular.com/mealplanner/generate?timeFrame=$timeFrame&Calories=$extractedNumber&maxFat=$maxFat&apiKey=$apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        String mealPlanMessage = '';
        if (timeFrame == 'day') {
          // Handle day timeframe response
          List<dynamic> meals = jsonData['meals'];
          mealPlanMessage = 'Your meal plan for the day:\n';
          for (var meal in meals) {
            String mealTitle = meal['title'];
            mealPlanMessage += '- $mealTitle\n';
          }
        } else if (timeFrame == 'week') {
          // Handle week timeframe response
          Map<String, dynamic> weekData = jsonData['week'];
          weekData.forEach((key, value) {
            mealPlanMessage += 'Meals for $key:\n';
            List<dynamic> meals = value['meals'];
            for (var meal in meals) {
              String mealTitle = meal['title'];
              mealPlanMessage += '- $mealTitle\n';
            }
            mealPlanMessage += '\n'; // Add newline for readability
          });
        }

        // Set state to add message to the chat
        setState(() {
          addMessage(Message(text: DialogText(text: [mealPlanMessage])), false);
        });
      } else {
        print(
            'Failed to fetch data from Spoonacular API. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching data from Spoonacular API: $e');
    }
  }

  Future<void> fetchDialogFlowResponse(String text) async {
    try {
      // Call Dialogflow API to get response
      DetectIntentResponse response = await dialogFlowtter.detectIntent(
        queryInput: QueryInput(text: TextInput(text: text)),
      );

      // Add Dialogflow response to messages
      setState(() {
        addMessage(response.message!);
      });
    } catch (e) {
      print('Error fetching data from Dialogflow: $e');
    }
  }

  addMessage(Message message, [bool isUserMessage = false]) {
    setState(() {
      messages.add({'message': message, 'isUserMessage': isUserMessage});
    });
  }
}