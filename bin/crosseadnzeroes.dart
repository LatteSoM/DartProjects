import 'dart:io';
import 'dart:math';

void main() {
  SeaBattleGame game = SeaBattleGame();
  game.start();
}

class SeaBattleGame {
  late Player player1;
  late Player bot;
  late int gridSize;
  final List<int> allowedGridSizes = [10, 14, 20];

  void start() {
    print("Добро пожаловать в игру 'Морской бой'!");

    _setupGame();
    print("Начинаем игру!");

    bool isPlayerTurn = true;
    while (true) {
      if (isPlayerTurn) {
        print("${player1.name}, ваш ход.");
        player1.displayGrids();
        player1.makeMove(bot);
        if (bot.isDefeated()) {
          print("Поздравляем, ${player1.name}! Вы победили!");
          break;
        }
      } else {
        print("Ходит бот...");
        bot.makeMove(player1);
        if (player1.isDefeated()) {
          print("Бот победил. Попробуйте снова!");
          break;
        }
      }
      isPlayerTurn = !isPlayerTurn;
      _pauseAndClear();
    }
  }

  void _setupGame() {
    print("Введите ваше имя:");
    String name = stdin.readLineSync()!;
    gridSize = _chooseGridSize();
    player1 = Player(name, gridSize);
    bot = Bot(gridSize);

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
          _processMove(x, y, opponent);
          return;
        }
      }
      print("Неверный ход. Попробуйте снова.");
    }
  }

  bool _isValidMove(int x, int y, List<List<String>> grid) {
    // Проверяем границы поля
    if (x < 0 || y < 0 || x >= gridSize || y >= gridSize) {
      print("Координаты вне допустимого диапазона. Попробуйте снова.");
      return false;
    }
    // Проверяем, что клетка ещё не атакована
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
  Random random = Random();

  Bot(int gridSize) : super("Бот", gridSize);

  @override
  void makeMove(Player opponent) {
    while (true) {
      int x = random.nextInt(gridSize);
      int y = random.nextInt(gridSize);
      if (_isValidMove(x, y, opponent.grid)) {
        print("Бот атакует: $x $y");
        _processMove(x, y, opponent);
        return;
      }
    }
  }

  @override
  void displayGrids() {
    // Бот не показывает своё поле
  }
}

class Ship {
  final int size;
  List<Point> positions = [];

  Ship(this.size);

  bool isSunk(List<List<String>> grid) {
    return positions.every((point) => grid[point.y.toInt()][point.x.toInt()] == 'X');
  }
}
