notes = [440]
delta = 2**(1/12)
for i in range(12):
    n = notes[-1] * delta
    n = round(n, 0)
    notes.append(n)

print(list(map(int, notes)))

