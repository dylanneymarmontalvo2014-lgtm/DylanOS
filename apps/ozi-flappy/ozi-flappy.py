#!/usr/bin/env python3
"""Flappy Bird ASCII para la consola de DylanOS."""
import argparse
import curses
import random


class Game:
    def __init__(self, width=36, height=12, gap=4, seed=7):
        if width < 18 or height < 8 or gap < 3 or gap >= height - 1:
            raise ValueError("El área de juego es demasiado pequeña")
        self.width, self.height, self.gap = width, height, gap
        self.rng = random.Random(seed)
        self.y = height // 2
        self.velocity = 0
        self.pipe_x = width - 2
        self.gap_y = self._new_gap()
        self.score = 0
        self.alive = True
        self.passed = False

    def _new_gap(self):
        return self.rng.randint(1, self.height - self.gap - 1)

    def flap(self):
        if self.alive:
            self.velocity = -2

    def tick(self):
        if not self.alive:
            return
        self.velocity = min(self.velocity + 1, 2)
        self.y += self.velocity
        self.pipe_x -= 1
        if self.pipe_x < 0:
            self.pipe_x = self.width - 2
            self.gap_y = self._new_gap()
            self.passed = False
        if self.y < 0 or self.y >= self.height:
            self.alive = False
            return
        if self.pipe_x == 2:
            if not self.gap_y <= self.y < self.gap_y + self.gap:
                self.alive = False
            elif not self.passed:
                self.score += 1
                self.passed = True


def _self_test():
    game = Game()
    game.flap()
    assert game.velocity == -2
    game.tick()
    assert game.y == game.height // 2 - 1 and game.alive
    for _ in range(100):
        game.tick()
        if not game.alive:
            break
    assert not game.alive
    print("Ozi Ozi Flappy: pruebas de estado OK")


def _draw(screen, game, hint=""):
    screen.erase()
    rows, cols = screen.getmaxyx()
    if rows < game.height + 6 or cols < game.width + 4:
        screen.addstr(0, 0, "Agrandá la terminal para jugar. Pulsa q para salir.")
        screen.refresh()
        return
    left, top = 2, 2
    screen.addstr(0, 2, "OZI OZI BIRD  |  ESPACIO: aletear  q: salir"[:max(0, cols - 3)])
    screen.addstr(1, 2, f"Puntos: {game.score}")
    screen.addstr(top, left, "+" + "-" * game.width + "+")
    for row in range(game.height):
        chars = [" "] * game.width
        px = game.pipe_x
        if 0 <= px < game.width and not game.gap_y <= row < game.gap_y + game.gap:
            chars[px] = "#"
        if row == max(0, min(game.height - 1, game.y)):
            chars[2] = "@"
        screen.addstr(top + 1 + row, left, "|" + "".join(chars) + "|")
    screen.addstr(top + game.height + 1, left, "+" + "-" * game.width + "+")
    if hint:
        screen.addstr(top + game.height + 3, left, hint[:max(0, cols - left - 1)])
    screen.refresh()


def _play(screen):
    curses.curs_set(0)
    screen.nodelay(True)
    screen.timeout(100)
    game = Game()
    started = False
    while True:
        key = screen.getch()
        if key in (ord("q"), ord("Q"), 27):
            return
        if key == ord(" ") and game.alive:
            started = True
            game.flap()
        if started and game.alive:
            game.tick()
        hint = ("Pulsa ESPACIO para empezar" if not started else
                (f"¡Choque! Puntuación: {game.score}. Pulsa q para salir" if not game.alive else ""))
        _draw(screen, game, hint)


def main():
    parser = argparse.ArgumentParser(description="Easter egg Flappy Bird de Ozi Ozi")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        _self_test()
        return 0
    try:
        curses.wrapper(_play)
    except curses.error as error:
        print(f"No se pudo iniciar Ozi Ozi Bird en esta terminal: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
