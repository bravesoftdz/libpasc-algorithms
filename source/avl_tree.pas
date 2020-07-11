(******************************************************************************)
(*                             libPasC-Algorithms                             *)
(*       object pascal library of common data structures and algorithms       *)
(*                 https://github.com/fragglet/c-algorithms                   *)
(*                                                                            *)
(* Copyright (c) 2020                                       Ivan Semenkov     *)
(* https://github.com/isemenkov/libpasc-algorithms          ivan@semenkov.pro *)
(*                                                          Ukraine           *)
(******************************************************************************)
(*                                                                            *)
(* This source  is free software;  you can redistribute  it and/or modify  it *)
(* under the terms of the GNU General Public License as published by the Free *)
(* Software Foundation; either version 3 of the License.                      *)
(*                                                                            *)
(* This code is distributed in the  hope that it will  be useful, but WITHOUT *)
(* ANY  WARRANTY;  without even  the implied  warranty of MERCHANTABILITY  or *)
(* FITNESS FOR A PARTICULAR PURPOSE.  See the  GNU General Public License for *)
(* more details.                                                              *)
(*                                                                            *)
(* A copy  of the  GNU General Public License is available  on the World Wide *)
(* Web at <http://www.gnu.org/copyleft/gpl.html>. You  can also obtain  it by *)
(* writing to the Free Software Foundation, Inc., 51  Franklin Street - Fifth *)
(* Floor, Boston, MA 02110-1335, USA.                                         *)
(*                                                                            *)
(******************************************************************************)

unit avl_tree;

{$mode objfpc}{$H+}
{$IFOPT D+}
  {$DEFINE DEBUG}
{$ENDIF}

interface

uses
  SysUtils;

type
  { The AVL tree structure is a balanced binary tree which stores a collection 
    of nodes. Each node has a key and a value associated with it. The nodes are 
    sorted within the tree based on the order of their keys. Modifications to 
    the tree are constructed such that the tree remains balanced at all times 
    (there are always roughly equal numbers of nodes on either side of the 
    tree).

    Balanced binary trees have several uses. They can be used as a mapping 
    (searching for a value based on its key), or as a set of keys which is 
    always ordered. }
  generic TAvlTree<K, V> = class
  public
    { Create a new AVL tree. }
    constructor Create;

    { Destroy an AVL tree. }
    destructor Destroy; override;

    { Insert a new key-value pair into an AVL tree. }
    procedure Insert (Key : K; Value : V);

    { Remove an entry from a tree, specifying the key of the node to remove. 
      Return false if no node with the specified key was found in the tree, true
      if a node with the specified key was removed. }
    function Remove (Key : K) : Boolean;

    { Search an AVL tree for a value corresponding to a particular key. This 
      uses the tree as a mapping. }
    function Search (Key : K) : V;
  protected
    type
      TAvlTreeNodeSide = (
        AVL_TREE_NODE_LEFT                                               = 0,
        AVL_TREE_NODE_RIGHT                                              = 1
      );

      PPAvlTreeNode = ^PAvlTreeNode;
      PAvlTreeNode = ^TAvlTreeNode;
      TAvlTreeNode = record
        children : array [0 .. 1] of PAvlTreeNode;
        parent : PAvlTreeNode;
        key : K;
        value : V;
        height : Integer;
      end;

      PAvlTree = ^TAvlTree;
      TAvlTree = record
        root_node : PAvlTreeNode;
        num_nodes : Cardinal;
      end;  
  protected
    { Free node. }
    procedure FreeSubTreeNode (node : PAvlTreeNode);

    { Remove a node from a tree. }
    procedure RemoveNode (node : PAvlTreeNode);

    { Search an AVL tree for a node with a particular key.  This uses the tree 
      as a mapping. }
    function SearchNode (key : K) : PAvlTreeNode;

    { Find the root node of a tree. }
    function RootNode : PAvlTreeNode;

    { Retrieve the key for a given tree node. }
    function NodeKey (node : PAvlTreeNode) : K;

    { Retrieve the value at a given tree node. }
    function NodeValue (node : PAvlTreeNode) : V;

    { Find the child of a given tree node. }
    function NodeChild (node : PAvlTreeNode; side : TAvlTreeNodeSide) : 
      PAvlTreeNode;
    
    { Find the parent node of a given tree node. }
    function NodeParent (node : PAvlTreeNode) : PAvlTreeNode;

    { Find the height of a subtree. }
    function SubTreeHeight (node : PAvlTreeNode) : Integer;
  protected
    { Update the "height" variable of a node, from the heights of its children. 
      This does not update the height variable of any parent nodes. }
    procedure UpdateTreeHeight (node : PAvlTreeNode);

    { Find what side a node is relative to its parent. }
    function TreeNodeParentSide (node : TAvlTreeNode) : TAvlTreeNodeSide;

    { Replace node1 with node2 at its parent. }
    procedure TreeNodeReplace (node1 : PAvlTreeNode; node2 : PAvlTreeNode);

    { Rotate a section of the tree. 'node' is the node at the top of the section 
      to be rotated. 'direction' is the direction in which to rotate the tree: 
      left or right, as shown in the following diagram: 

      Left rotation:              Right rotation:
 
           B                             D
          / \                           / \
         A   D                         B   E
            / \                       / \
           C   E                     A   C
      is rotated to:              is rotated to:
      
             D                           B
            / \                         / \
           B   E                       A   D
          / \                             / \
         A   C                           C   E                                    }
    function TreeRotate (node : PAvlTreeNode; direction : TAVLTreeNodeSide) :
      PAvlTreeNode;

    { Balance a particular tree node. 

      Returns the root node of the new subtree which is replacing the old one. }
    function TreeNodeBalance (node : PAvlTreeNode) : PAvlTreeNode;

    { Walk up the tree from the given node, performing any needed rotations. }
    procedure TreeBalanceToRoot (node : PAvlTreeNode);
  protected
    FTree : PAvlTree;
  end;

implementation

constructor TAvlTree.Create;
begin
  New(FTree);
  FTree^.root_node := nil;
  FTree^.num_nodes := 0;
end;

procedure TAvlTree.FreeSubTreeNode (node : PAvlTreeNode);
begin
  if node <> nil then
  begin
    FreeSubtreeNode(node^.children[AVL_TREE_NODE_LEFT]);
    FreeSubtreeNode(node^.children[AVL_TREE_NODE_RIGHT]);

    Dispose(node);
    node := nil;
  end;
end;

destructor TAvlTree.Destroy;
begin
  { Destroy all nodes }
  FreeSubtreeNode(FTree^.root_node);
  { Free back the main tree data structure }
  Dispose(FTree);
  FTree := nil;

  inherited Destroy;
end;

function TAvlTree.SubTreeHeight (node : PAvlTreeNode) : Integer;
begin
  if node <> nil then
  begin
    Result := node^.height;
  end else
  begin
    Result := 0;
  end;
end;

procedure TAlvTree.UpdateTreeHeight (node : PAvlTreeNode);
var
  left_subtree : PAvlTreeNode;
  right_subtree : PAvlTreeNode;
  left_height, right_height : Integer;
begin
  left_subtree := node^.children[AVL_TREE_NODE_LEFT];
  right_subtree := node^.children[AVL_TREE_NODE_RIGHT];
  left_height := SubTreeHeight(left_subtree);
  right_height := SubTreeHeight(right_subtree);

  if left_height > right_height then
  begin
    node^.height := left_height + 1;
  end else 
  begin
    node^.height := right_height + 1;
  end;
end;

function TAvlTree.TreeNodeParentSide (node : TAvlTreeNode) : TAvlTreeNodeSide;
begin
  if node^.parent^.children[AVL_TREE_NODE_LEFT] = node then
  begin
    Result := AVL_TREE_NODE_LEFT;
  end else
  begin
    Result := AVL_TREE_NODE_RIGHT;
  end;
end;

procedure TAvlTree.TreeNodeReplace (node1 : PAvlTreeNode; node2 : PAvlTreeNode);
var
  side : Integer;
begin
  { Set the node's parent pointer. }
  if node2 <> nil then
  begin
    node2^.parent := node1^.parent;
  end;

  { The root node? }
  if node1^.parent = nil then
  begin
    FTree^.root_node := node2;
  end else begin
    side := TreeNodeParentSide(node1);
    node1^.parent^.children[side] := node2;
    UpdateTreeHeight(node1^.parent);
  end;
end;

function TAvlTree.TreeRotate (node : PAvlTreeNode; direction : TAVLTreeNodeSide) 
  : PAvlTreeNode;
var
  new_root : PAvlTreeNode;
begin
  { The child of this node will take its place:
	  for a left rotation, it is the right child, and vice versa. }
  new_root := node^.children[1 - direction];

  { Make new_root the root, update parent pointers. }
  TreeNodeReplace(node, new_root);

  { Rearrange pointers }
  node^.children[1 - direction] := new_root^.children[direction];
  new_root^.children[direction] := node;

  { Update parent references }
  node^.parent := new_root;

  if node^.children[1 - direction] <> nil then
  begin
    node^.children[1 - direction]^.parent := node;
  end;

  { Update heights of the affected nodes }
  UpdateTreeHeight(new_root);
  UpdateTreeHeight(node);

  Result := new_root;
end;

function TAvlTree.TreeNodeBalance (node : PAvlTreeNode) : PAvlTreeNode;
var
  left_subtree : PAvlTreeNode;
  right_subtree : PAvlTreeNode;
  child : PAvlTreeNode;
  diff : Integer;
begin
  left_subtree := node^.children[AVL_TREE_NODE_LEFT];
  right_subtree := node^.children[AVL_TREE_NODE_RIGHT];

  { Check the heights of the child trees. If there is an unbalance (difference 
    between left and right > 2), then rotate nodes around to fix it. }
  diff := SubTreeHeight(right_subtree) - SubTreeHeight(left_subtree);

  if diff >= 2 then
  begin
    { Biased toward the right side too much. }
    child := right_subtree;

    if SubTreeHeight(child^.children[AVL_TREE_NODE_RIGHT]) <
       SubTreeHeight(child^.children[AVL_TREE_NODE_LEFT]) then
    begin
      { If the right child is biased toward the left side, it must be rotated 
        right first (double rotation). }
      TreeRotate(right_subtree, AVL_TREE_NODE_RIGHT);
    end;  

    { Perform a left rotation. After this, the right child will take the place 
      of this node. Update the node pointer. }
    node := TreeRotate(node, AVL_TREE_NODE_LEFT);
  end else if diff <= -2 then
  begin
    { Biased toward the left side too much. }
    child := node^.children[AVL_TREE_NODE_LEFT];

    if SubTreeHeight(child^.children[AVL_TREE_NODE_LEFT]) <
       SubTreeHeight(child^.children[AVL_TREE_NODE_RIGHT]) then
    begin
      { If the left child is biased toward the right side, it must be rotated 
        right left (double rotation). }
      TreeRotate(left_subtree, AVL_TREE_NODE_LEFT);
    end; 

    { Perform a right rotation. After this, the left child will take the place 
      of this node. Update the node pointer. }
    node := TreeRotate(node, AVL_TREE_NODE_RIGHT);
  end;

  { Update the height of this node. }
  UpdateTreeHeight(node);
  Result := node;
end;

procedure TAvlTree.TreeBalanceToRoot (node : PAvlTreeNode);
var
  rover : PAvlTreeNode;
begin
  rover := node;
  while rover <> nil do
  begin
    { Balance this node if necessary. }
    rover := TreeNodeBalance(rover);  

    { Go to this node's parent. }
    rover := rover^.parent;
  end;
end;

procedure TAvlTree.Insert (Key : K; Value : V);
var
  rover : PPAvlTreeNode;
  new_node : PAvlTreeNode;
  previous_node : PAvlTreeNode;
begin
  { Walk down the tree until we reach a NULL pointer. }
  rover := @(FTree^.root_node);
  previous_node := nil;

  while rover^ <> nil do
  begin
    previous_node := rover^;
    if Key < (rover^)^.key then
    begin
      rover := @((rover^)^.children[AVL_TREE_NODE_LEFT]);
    end else
    begin
      rover := @((rover^)^.children[AVL_TREE_NODE_RIGHT]);
    end;
  end;

  { Create a new node. Use the last node visited as the parent link. }
  New(new_node);
  new_node^.children[AVL_TREE_NODE_LEFT] := nil;
  new_node^.children[AVL_TREE_NODE_RIGHT] := nil;
  new_node^.parent := previous_node;
  new_node^.key := Key;
  new_node^.value := Value;
  new_node^.height := 1;

  { Insert at the NULL pointer that was reached. }
  rover^ := new_node;

  { Rebalance the tree, starting from the previous node. }
  TreeBalanceToRoot(previous_node);

  { Keep track of the number of entries. }
  Inc(FTree^.num_nodes);
  Result := new_node;
end;

end.