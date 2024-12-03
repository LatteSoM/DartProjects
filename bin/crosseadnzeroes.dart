import 'dart:io';
import 'dart:math';

void main() {
  while (true) {
    print('Выберите режим игры:');
    print('1. Играть с кентом');
    print('2. Играть против бездушной машины');
    String? mode = stdin.readLineSync();

    print('Введите размер для поля битвы (например, 3 для 3x3):');
    int size = int.parse(stdin.readLineSync()!);
    
    play(size, mode == '2');
    
    print('Хотите повеселиться еще раз? (y/n)');
    String? playAgain = stdin.readLineSync();
    if (playAgain?.toLowerCase() != 'y') {
      break;
    }
  }
}

void play(int size, bool withAi) {
  List<List<String>> field = List.generate(size, (_) => List.filled(size, ' '));
  String currentPlayer = Random().nextBool() ? 'X' : 'O';
  bool endGame = false;

  while (!endGame && !isFielddFull(field)) {
    printField(field);
    if (currentPlayer == 'X' || !withAi) {
      print('Игрок $currentPlayer, введите ваши координаты (строка и столбец):');
      String? input = stdin.readLineSync();
      List<int> move = input!.split(' ').map(int.parse).toList();
      if (isValidMove(field, move[0], move[1])) {
        field[move[0]][move[1]] = currentPlayer;
      } else {
        print('цифры правильно вводи через пробела да.');
        continue;
      }
    } else {
      // Ход робота
      print('Ход бездушной машины...');
      makeRobotMove(field, currentPlayer);
    }

    endGame = winCheck(field, currentPlayer);
    if (!endGame) {
      currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
    }
  }

  printField(field);
  if (endGame) {
    print('Игрок $currentPlayer размотал котенка!');
  } else {
    print('Игра закончилась взаимным уважением!');
  }
}

void printField(List<List<String>> field) {
  for (var row in field) {
    print(row.join('|'));
    print('-' * (row.length * 2 - 1));
  }
}

bool isValidMove(List<List<String>> field, int row, int col) {
  return row >= 0 && row < field.length && col >= 0 && col < field.length && field[row][col] == ' ';
}

bool isFielddFull(List<List<String>> field) {
  for (var row in field) {
    if (row.contains(' ')) {
      return false;
    }
  }
  return true;
}

bool winCheck(List<List<String>> field, String player) {
  // Проверка строк и столбцов
  for (int i = 0; i < field.length; i++) {
    if (field[i].every((yacheyka) => yacheyka == player) || 
        field.map((row) => row[i]).every((yacheyka) => yacheyka == player)) {
      return true;
    }
  }

  // Проверка диагоналей
  if (List.generate(field.length, (i) => field[i][i]).every((yacheyka) => yacheyka == player) ||
      List.generate(field.length, (i) => field[i][field.length - 1 - i]).every((yacheyka) => yacheyka == player)) {
    return true;
  }

  return false;
}

void makeRobotMove(List<List<String>> field, String player) {
  String visavi = player == 'X' ? 'O' : 'X';

  // Сначала проверяем, может ли робот выиграть в следующем ходе
  for (int i = 0; i < field.length; i++) {
    for (int j = 0; j < field.length; j++) {
      if (field[i][j] == ' ') {
        field[i][j] = player;
        if (winCheck(field, player)) {
          return; // Если выиграл, делаем ход
        }
        field[i][j] = ' '; // Возвращаем обратно
      }
    }
  }

  // Затем проверяем, может ли игрок выиграть в следующем ходе, и блокируем его
  for (int i = 0; i < field.length; i++) {
    for (int j = 0; j < field.length; j++) {
      if (field[i][j] == ' ') {
        field[i][j] = visavi;
        if (winCheck(field, visavi)) {
          field[i][j] = player; // Блокируем ход игрока
          return;
        }
        field[i][j] = ' '; // Возвращаем обратно
      }
    }
  }

  // Если нет угрозы, делаем случайный ход
  List<List<int>> emptyFields = [];
  for (int i = 0; i < field.length; i++) {
    for (int j = 0; j < field.length; j++) {
      if (field[i][j] == ' ') {
        emptyFields.add([i, j]);
      }
    }
  }

  if (emptyFields.isNotEmpty) {
    var randomMove = emptyFields[Random().nextInt(emptyFields.length)];
    field[randomMove[0]][randomMove[1]] = player;
  }
}
