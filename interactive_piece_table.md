
# Inserting

```py
# Insert text right before piece
def InsertBeforePiece(table, index, text):
    piece := GetPrevious(table.pieces, index)
    if piece is not null:
        if PieceIsAppendable(piece):
            AppendToPiece(piece, text)
        else:
            AddPiece(table.piece, index)
            InsertBeforePiece(table.piece, index)

```