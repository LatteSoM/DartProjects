import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

void main() {
  SeaBattleGame game = SeaBattleGame();
  game.start();
}

class FileManager {
  final String playerDataDir = 'C:/flutter_projects/crosses/crosseadnzeroes/player_data';
  final String gameDataFile = 'current_game.txt';
  final String logFile = 'game_log.txt';

  FileManager() {
    Directory(playerDataDir).createSync(recursive: true);
  }

  Future<void> initializePlayerFile(String playerName) async {
    final file = File("./${playerName}.txt");
    if (!(await file.exists())) {
      await file.writeAsString('Игрок: $playerName\nИгр сыграно: 0\nПобед: 0\nПоражений: 0\n');
    }
  }

  Future<void> updateStats(String playerName, {required bool isWinner}) async {
    final file = File('.T/$playerName.txt');
    if (!(await file.exists())) return;

    final lines = await file.readAsLines();
    int gamesPlayed = int.parse(lines[1].split(': ')[1]);
    int wins = int.parse(lines[2].split(': ')[1]);
    int losses = int.parse(lines[3].split(': ')[1]);

    gamesPlayed++;
    if (isWinner) {
      wins++;
    } else {
      losses++;
    }

    await file.writeAsString('''Игрок: $playerName Игр сыграно: $gamesPlayed Побед: $wins Поражений: $losses''');
  }

  Future<void> logMove(String attacker, String defender, Point move, String result) async {
    final logEntry = '$attacker атаковал ($move): $result\n';
    await _writeToFile(logFile, logEntry);
  }

  Future<void> clearGameFile() async {
    final file = File(gameDataFile);
    if (await file.exists()) {
      await file.writeAsString('');
    }
  }

  Future<void> _writeToFile(String filePath, String content) async {
    final file = File(filePath);
    await file.writeAsString(content, mode: FileMode.append, flush: true);
  }
}

class LogIsolate {
  late Isolate _isolate;
  late SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  Future<void> initialize() async {
    _isolate = await Isolate.spawn(_logIsolate, _receivePort.sendPort);
    _sendPort = await _receivePort.first as SendPort;
  }

  void log(String message) {
    _sendPort.send(message);
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }

  static void _logIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final logFile = File('async_log.txt');
    receivePort.listen((message) async {
      await logFile.writeAsString('$message\n', mode: FileMode.append, flush: true);
    });
  }
}

class SeaBattleGame {
  late Player player1;
  late Player bot;
  late int gridSize;
  final List<int> allowedGridSizes = [10, 14, 20];

  final FileManager fileManager = FileManager();

  Future<void> start() async {
    print("Добро пожаловать в игру 'Морской бой'!");

    await _setupGame();
    print("Начинаем игру!");

    bool isPlayerTurn = true;
    while (true) {
      if (isPlayerTurn) {
        print("${player1.name}, ваш ход.");
        player1.displayGrids();
        player1.makeMove(bot);
        await fileManager.logMove(player1.name, bot.name, player1.lastMove, bot.grid[player1.lastMove.y.toInt()][player1.lastMove.x.toInt()]);

        if (bot.isDefeated()) {
          print("Поздравляем, ${player1.name}! Вы победили!");
          await fileManager.updateStats(player1.name, isWinner: true);
          await fileManager.updateStats(bot.name, isWinner: false);
          break;
        }
      } else {
        print("Ходит бот...");
        bot.makeMove(player1);
        await fileManager.logMove(bot.name, player1.name, bot.lastMove, player1.grid[bot.lastMove.y.toInt()][bot.lastMove.x.toInt()]);

        if (player1.isDefeated()) {
          print("Бот победил. Попробуйте снова!");
          await fileManager.updateStats(player1.name, isWinner: false);
          await fileManager.updateStats(bot.name, isWinner: true);
          break;
        }
      }
      isPlayerTurn = !isPlayerTurn;
      _pauseAndClear();
    }

    await fileManager.clearGameFile();
    print("Игра завершена!");
  }

  Future<void> _setupGame() async {
    print("Введите ваше имя:");
    String name = stdin.readLineSync() ?? 'Игрок';
    gridSize = _chooseGridSize();
    player1 = Player(name, gridSize);
    bot = Bot(gridSize);

    await fileManager.initializePlayerFile(player1.name);
    await fileManager.initializePlayerFile(bot.name);

    print("Разместите свои корабли на поле!");
    player1.placeShips();
    print("Бот размещает свои корабли...");
    bot.placeShips();
    _pauseAndClear();
  }

  int _chooseGridSize() {
    print("Выберите размер поля: ${allowedGridSizes.join(", ")}");
    while (true) {
      String? input = stdin.readLineSync();
      int? size = int.tryParse(input ?? '');
      if (size != null && allowedGridSizes.contains(size)) {
        return size;
      }
      print("Неверный ввод. Попробуйте снова.");
    }
  }

  void _pauseAndClear() {
    print("Нажмите Enter для продолжения...");
    stdin.readLineSync();
    print("\x1B[2J\x1B[0;0H"); // Очищает консоль
  }
}

class Player {
  final String name;
  final int gridSize;
  late List<List<String>> grid;
  late List<List<String>> enemyGrid;
  late List<Ship> ships;
  late Point lastMove;

  Player(this.name, this.gridSize) {
    grid = List.generate(gridSize, (_) => List.filled(gridSize, ' '));
    enemyGrid = List.generate(gridSize, (_) => List.filled(gridSize, ' '));
    ships = [];
  }

  void placeShips() {
    _autoPlaceShips();
  }

  void _autoPlaceShips() {
    Random random = Random();
    List<int> shipSizes = [5, 4, 3, 3, 2];
    for (int size in shipSizes) {
      while (true) {
        int x = random.nextInt(gridSize);
        int y = random.nextInt(gridSize);
        bool horizontal = random.nextBool();
        if (_canPlaceShip(x, y, size, horizontal)) {
          _placeShip(x, y, size, horizontal);
          break;
        }
      }
    }
  }

  bool _canPlaceShip(int x, int y, int size, bool horizontal) {
    for (int i = 0; i < size; i++) {
      int nx = x + (horizontal ? i : 0);
      int ny = y + (horizontal ? 0 : i);
      if (nx >= gridSize || ny >= gridSize || grid[ny][nx] != ' ') return false;
    }
    return true;
  }

  void _placeShip(int x, int y, int size, bool horizontal) {
    Ship ship = Ship(size);
    for (int i = 0; i < size; i++) {
      int nx = x + (horizontal ? i : 0);
      int ny = y + (horizontal ? 0 : i);
      grid[ny][nx] = 'S';
      ship.positions.add(Point(nx, ny));
    }
    ships.add(ship);
  }

  void displayGrids() {
    print("Ваше поле:");
    _printGrid(grid);
    print("\nПоле противника:");
    _printGrid(enemyGrid);
  }

  void _printGrid(List<List<String>> grid) {
    print("  ${List.generate(gridSize, (i) => i).join(' ')}");
    for (int y = 0; y < gridSize; y++) {
      String row = grid[y].join(' ');
      print("$y $row");
    }
  }

  void makeMove(Player opponent) {
    while (true) {
      print("Введите координаты атаки (например, 3 5):");
      String? input = stdin.readLineSync();
      List<String> parts = input?.split(' ') ?? [];
      if (parts.length == 2) {
        int? x = int.tryParse(parts[0]);
        int? y = int.tryParse(parts[1]);
        if (x != null && y != null && _isValidMove(x, y, opponent.grid)) {
          lastMove = Point(x, y);
          _processMove(x, y, opponent);
          return;
        }
      }
      print("Неверный ход. Попробуйте снова.");
    }
  }

  bool _isValidMove(int x, int y, List<List<String>> grid) {
    if (x < 0 || y < 0 || x >= gridSize || y >= gridSize) {
      print("Координаты вне допустимого диапазона. Попробуйте снова.");
      return false;
    }
    if (grid[y][x] == '.' || grid[y][x] == 'X') {
      print("Вы уже атаковали эту клетку. Попробуйте другую.");
      return false;
    }
    return true;
  }

  void _processMove(int x, int y, Player opponent) {
    if (opponent.grid[y][x] == 'S') {
      print("Попадание!");
      opponent.grid[y][x] = 'X';
      enemyGrid[y][x] = 'X';
    } else {
      print("Мимо.");
      opponent.grid[y][x] = '.';
      enemyGrid[y][x] = '.';
    }
  }

  bool isDefeated() {
    return ships.every((ship) => ship.isSunk(grid));
  }
}

class Bot extends Player {
  Bot(int gridSize) : super("Бот", gridSize);

  void makeMove(Player opponent) {
    Random random = Random();
    while (true) {
      int x = random.nextInt(gridSize);
      int y = random.nextInt(gridSize);
      if (_isValidMove(x, y, opponent.grid)) {
        lastMove = Point(x, y);
        _processMove(x, y, opponent);
        return;
      }
    }
  }
}

class Ship {
  final int size;
  final List<Point> positions = [];

  Ship(this.size);

  bool isSunk(List<List<String>> grid) {
    return positions.every((pos) => grid[pos.y.toInt()][pos.x.toInt()] == 'X');
  }
}
