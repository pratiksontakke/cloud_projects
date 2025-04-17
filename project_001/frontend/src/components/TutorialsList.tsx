
import React from "react";
import { 
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow 
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { 
  Edit, 
  Trash2, 
  Eye,
  Check,
  X
} from "lucide-react";
import { Tutorial } from "@/services/tutorialService";

interface TutorialsListProps {
  tutorials: Tutorial[];
  onEdit: (tutorial: Tutorial) => void;
  onDelete: (id: number) => void;
  onView: (id: number) => void;
}

const TutorialsList: React.FC<TutorialsListProps> = ({
  tutorials,
  onEdit,
  onDelete,
  onView,
}) => {
  return (
    <div className="bg-white rounded-md shadow animate-fade-in">
      <Table>
        <TableCaption>List of all tutorials</TableCaption>
        <TableHeader>
          <TableRow>
            <TableHead className="w-[50px]">ID</TableHead>
            <TableHead>Title</TableHead>
            <TableHead>Description</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {tutorials.length > 0 ? (
            tutorials.map((tutorial) => (
              <TableRow key={tutorial.id}>
                <TableCell className="font-medium">{tutorial.id}</TableCell>
                <TableCell className="font-medium">{tutorial.title}</TableCell>
                <TableCell className="max-w-[300px] truncate">
                  {tutorial.description || "-"}
                </TableCell>
                <TableCell>
                  {tutorial.published ? (
                    <Badge className="bg-green-500 hover:bg-green-600 flex w-fit gap-1 items-center">
                      <Check size={12} /> Published
                    </Badge>
                  ) : (
                    <Badge variant="outline" className="flex w-fit gap-1 items-center">
                      <X size={12} /> Draft
                    </Badge>
                  )}
                </TableCell>
                <TableCell className="text-right">
                  <div className="flex justify-end gap-2">
                    <Button
                      variant="outline"
                      size="icon"
                      onClick={() => onView(tutorial.id!)}
                      title="View details"
                    >
                      <Eye size={16} />
                    </Button>
                    <Button
                      variant="outline"
                      size="icon"
                      onClick={() => onEdit(tutorial)}
                      title="Edit tutorial"
                    >
                      <Edit size={16} />
                    </Button>
                    <Button
                      variant="destructive"
                      size="icon"
                      onClick={() => onDelete(tutorial.id!)}
                      title="Delete tutorial"
                    >
                      <Trash2 size={16} />
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))
          ) : (
            <TableRow>
              <TableCell colSpan={5} className="text-center py-8 text-muted-foreground">
                No tutorials found. Create one to get started.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
};

export default TutorialsList;
